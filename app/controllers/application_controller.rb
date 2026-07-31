class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  around_action :use_request_locale

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
end
