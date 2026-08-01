# ログイン状態の読み書きをまとめる。
#
# Cookie に入れるのはセッションのレコード ID だけとする。
# 署名付き Cookie を使い、値の書き換えを検出できる状態にする。
# 方針は docs/decisions/0007-database-backed-sessions.md を正本とする。
module Authentication
  extend ActiveSupport::Concern

  SESSION_COOKIE = :session_id

  # ログイン後に戻る先を覚えておく鍵。Rails のセッション（Cookie）へ置く。
  RETURN_TO_KEY = :return_to

  # 戻り先として受け入れる形。同じサイトの絶対パスだけとする。
  # 別サイトの URL を受け入れると、ログイン直後に外部へ送る踏み台になる。
  # `//example.com` は scheme 相対の外部 URL であるため除く。
  INTERNAL_PATH = %r{\A/(?!/)[^\\]*\z}

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

    # ログインを必須にする。
    #
    # 既定では認証を求めず、必要な画面が自分で宣言する。
    # 既定で全画面を保護すると、公開画面を足すたびに除外の宣言が要る。
    # 除外の書き忘れは画面が出ないだけで済むが、宣言の書き忘れは公開につながる
    # ——という理由で既定を保護側にする考え方もある。
    # ここでは公開画面が主である段階に合わせ、宣言側を選ぶ。
    def require_authentication
      return if signed_in?

      store_return_to
      redirect_to new_session_path(locale: I18n.locale)
    end

    # メールアドレスの確認を必須にする。
    #
    # ログイン自体は拒まない。拒むと、確認メールが届かなかった利用者が
    # 再送を依頼する手段まで失う。
    def require_confirmed_email
      return if current_user&.confirmed?

      render "confirmations/pending", status: :forbidden
    end

    def store_return_to
      session[RETURN_TO_KEY] = request.fullpath if request.get?
    end

    # 覚えていた戻り先を 1 度だけ返す。
    # 残したままにすると、次のログインでも同じ場所へ送られる。
    def return_to_after_authentication
      path = session.delete(RETURN_TO_KEY)

      path if path.to_s.match?(INTERNAL_PATH)
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
