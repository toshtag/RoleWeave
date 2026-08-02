class ApplicationController < ActionController::Base
  # 繰り返しの試行の上限と期間。
  #
  # 総当たり（ログイン）、大量作成（登録）、
  # 大量送信（再設定の依頼・メッセージ・招待）を抑える。
  # 値はここ 1 か所に置く。経路ごとに書くと、片方だけ緩めた状態が生まれる。
  # 詳細は docs/decisions/0044-rate-limiting.md を参照する。
  SIGN_IN_ATTEMPT_LIMIT = 10
  SIGN_UP_ATTEMPT_LIMIT = 5
  PASSWORD_RESET_ATTEMPT_LIMIT = 5
  MESSAGE_ATTEMPT_LIMIT = 30
  # 招待は宛先を選べる。届く先は、こちらの利用者とは限らない。
  # 通常の招待は数人であり、5 分で 10 件を超える使い方は想定しない。
  INVITATION_ATTEMPT_LIMIT = 10
  RATE_LIMIT_PERIOD = 5.minutes

  include Authentication

  # 対応外ブラウザーへ返す案内。日本語は拡張子を持たないファイルを正本とする。
  UNSUPPORTED_BROWSER_PAGE = "406-unsupported-browser".freeze

  # ロケールの適用を最初に登録する。
  #
  # Rails のコールバックは登録順に実行される。ここを後ろへ置くと、
  # 対応ブラウザーの判定が I18n.locale の既定値のまま動き、
  # 英語の URL でも日本語の案内が返る。
  around_action :use_request_locale

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  #
  # 既定の block は英語だけのページを描画する。表示言語の正本を URL とする
  # ADR 0001 の契約に合わせ、リクエストのロケールに対応するページへ差し替える。
  allow_browser versions: :modern, block: -> { render_unsupported_browser }

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # 構造化ログへ利用者の id を載せる。メールアドレスは載せない。
  # 詳細は docs/decisions/0048-structured-logging.md を参照する。
  def append_info_to_payload(payload)
    super

    payload[:user_id] = Current.session&.user_id
  end

  private
    # 上限を超えたときの応答。
    #
    # 例外ではないため exceptions_app を通らない。静的な画面を直接返す。
    # 描画経路を通さないのは、ほかのエラー画面と同じ理由による（ADR 0003）。
    def render_rate_limited
      page = I18n.locale == I18n.default_locale ? "429.html" : "429.#{I18n.locale}.html"

      render file: Rails.public_path.join(page), status: :too_many_requests, layout: false
    end

    # URL のロケールを、そのリクエストの間だけ適用する。
    #
    # I18n.locale への代入はスレッドローカルへ残るため、代入したままにすると
    # 同じスレッドを再利用する後続のリクエストへ前のリクエストの言語が漏れる。
    #
    # 対応外のロケールは route が受理しないため、ここでは救済しない。
    def use_request_locale(&action)
      I18n.with_locale(params[:locale] || I18n.default_locale, &action)
    end

    # 対応ブラウザーの下限を満たさない場合の案内。
    #
    # 406 は例外ではないため exceptions_app を通らない。
    # 他のエラー画面と同じく、Controller・View・アセットパイプラインへ依存させず、
    # public/ の静的 HTML をそのまま返す。
    def render_unsupported_browser
      render file: unsupported_browser_page, layout: false, status: :not_acceptable
    end

    # ActionDispatch::PublicExceptions と同じ規則でロケール別のファイルを選ぶ。
    # 406 だけ別の規則にすると、対応言語を増やしたときにここだけが取り残される。
    def unsupported_browser_page
      localized = Rails.public_path.join("#{UNSUPPORTED_BROWSER_PAGE}.#{I18n.locale}.html")

      localized.exist? ? localized : Rails.public_path.join("#{UNSUPPORTED_BROWSER_PAGE}.html")
    end
end
