# ログイン状態の読み書きをまとめる。
#
# Cookie に入れるのはセッションのレコード ID だけとする。
# 署名付き Cookie を使い、値の書き換えを検出できる状態にする。
# 方針は docs/decisions/0007-database-backed-sessions.md を正本とする。
module Authentication
  extend ActiveSupport::Concern

  SESSION_COOKIE = :session_id

  included do
    before_action :resume_session

    # View からも同じ判定を使う。ログイン状態の読み方が 2 通りあると、
    # 画面と処理で判断が食い違う。
    helper_method :signed_in?, :current_user
  end

  private
    # Cookie が指すセッションを読み出し、このリクエストの間だけ有効にする。
    #
    # 参照先が消えている Cookie は、ログイン状態として扱わない。
    # 署名が合っていても、対応するレコードがなければログアウト済みである。
    def resume_session
      session = Session.find_by(id: cookies.signed[SESSION_COOKIE])

      # 期限切れはその場で消す。残しておくと、判定する場所が増えるたびに
      # 「期限を見ているか」を確認して回ることになる。
      if session&.expired?
        session.destroy
        cookies.delete(SESSION_COOKIE)
        session = nil
      end

      session&.touch_activity

      Current.session = session
    end

    def signed_in?
      Current.session.present?
    end

    def current_user
      Current.user
    end

    def start_new_session_for(user)
      user.sessions.create!.tap do |session|
        Current.session = session

        cookies.signed[SESSION_COOKIE] = {
          value: session.id,
          # 発行からの上限に合わせる。permanent（20 年）を使うと、
          # サーバーがすでに無効とみなす Cookie をブラウザーが持ち続ける。
          expires: session.cookie_expires_at,
          # JavaScript から読めないようにする。読めると XSS がそのまま乗っ取りになる。
          httponly: true,
          # 別サイトからの遷移で Cookie を送らない。
          same_site: :lax
          # secure 属性は config.force_ssl に任せる。production で有効であり、
          # Rails が応答の Cookie を secure へ引き上げる。
        }
      end
    end

    def terminate_session
      Current.session&.destroy
      Current.session = nil
      cookies.delete(SESSION_COOKIE)
    end
end
