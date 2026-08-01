class ApplicationController < ActionController::Base
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

  private
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
