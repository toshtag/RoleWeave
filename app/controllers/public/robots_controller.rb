# 検索エンジンへ、たどってほしくない経路と sitemap の場所を伝える。
#
# 静的ファイルにすると、sitemap の URL にホスト名を書けない。
# 方針は docs/decisions/0024-structured-data-and-crawling.md を正本とする。
class Public::RobotsController < ApplicationController
  # たどらせない経路。ログインが要る画面と、token を持つ経路を並べる。
  #
  # 除外は「見えてはいけない」ための仕組みではない。
  # 到達できる URL は robots.txt に関わらず到達できる。
  # ここで避けるのは、意味のない巡回と、検索結果への露出である。
  DISALLOWED_PATHS = %w[
    /account
    /organizations
    /operator
    /session
    /registration
    /password_reset
    /confirmation
    /invitation
  ].freeze

  def show
    @disallowed_paths = I18n.available_locales.flat_map do |locale|
      DISALLOWED_PATHS.map { |path| "/#{locale}#{path}" }
    end
    @sitemap_url = sitemap_url

    # 内容は設定だけで決まり、ログイン状態に依存しない。
    expires_in 1.day, public: true

    render formats: :text, content_type: "text/plain"
  end
end
