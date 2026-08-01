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
      Current.session = Session.find_by(id: cookies.signed[SESSION_COOKIE])
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

        cookies.signed.permanent[SESSION_COOKIE] = {
          value: session.id,
          # JavaScript から読めないようにする。読めると XSS がそのまま乗っ取りになる。
          httponly: true,
          # 別サイトからの遷移で Cookie を送らない。
          same_site: :lax
        }
      end
    end

    def terminate_session
      Current.session&.destroy
      Current.session = nil
      cookies.delete(SESSION_COOKIE)
    end
end
