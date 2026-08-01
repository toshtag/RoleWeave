require "test_helper"

# 対応ブラウザーの下限を満たさない閲覧者へ返す案内の契約を検証する。
#
# 406 は例外ではない。allow_browser が登録する before_action が
# 静的ページを直接描画して処理を止めるため、exceptions_app を通らない。
# ロケール解決も、他のエラー画面とは別の経路で行う。
#
# 検証対象は「どの URL でどのページが返るか」であり、
# ページ自体の構造と外部依存は error_pages_test と shared_page_contract_test が持つ。
class UnsupportedBrowserTest < ActionDispatch::IntegrationTest
  # 対応ブラウザーの下限（versions: :modern）は Chrome 120 を要求する。
  # 下限そのものを検証する意図はないため、明確に下回る版と上回る版を使う。
  OUTDATED_BROWSER = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " \
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.0.0 Safari/537.36"

  SUPPORTED_BROWSER = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " \
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

  # 日本語は既定ロケールであり、拡張子なしのファイルを正本とする。
  # 406-unsupported-browser.ja.html は作らない。
  PAGES = {
    ja: "406-unsupported-browser.html",
    en: "406-unsupported-browser.en.html"
  }.freeze

  test "対応外のブラウザーで日本語の URL は日本語の案内を返す" do
    get "/ja", headers: { "User-Agent" => OUTDATED_BROWSER }

    assert_response :not_acceptable
    assert_page :ja
  end

  test "対応外のブラウザーで英語の URL は英語の案内を返す" do
    # ブラウザー判定は before_action であり、ロケールの適用より後に登録すると
    # 既定ロケールのまま動く。英語の URL でしか、その取り違えを検出できない。
    get "/en", headers: { "User-Agent" => OUTDATED_BROWSER }

    assert_response :not_acceptable
    assert_page :en
  end

  test "対応外のブラウザーへの案内を HTML として返す" do
    get "/ja", headers: { "User-Agent" => OUTDATED_BROWSER }

    assert_match %r{\Atext/html}, response.media_type.to_s + response.content_type.to_s
  end

  test "対応するブラウザーでは入口ページを返す" do
    # 判定が広すぎると、対応しているブラウザーまで締め出す。
    I18n.available_locales.each do |locale|
      get "/#{locale}", headers: { "User-Agent" => SUPPORTED_BROWSER }

      assert_response :success
      assert_select "main h1"
    end
  end

  test "User-Agent を持たないリクエストを遮断しない" do
    # 版を名乗らない相手を対応外と決めつけると、監視や巡回まで締め出す。
    get "/ja"

    assert_response :success
  end

  test "対応外のブラウザーへの応答の後にロケールを残さない" do
    # ブラウザー判定はロケールを適用する around_action の中で起こる。
    # 適用が閉じないと、同じスレッドを使う次のリクエストへ言語が漏れる。
    get "/en", headers: { "User-Agent" => OUTDATED_BROWSER }

    assert_equal I18n.default_locale, I18n.locale
  end

  private
    # 応答が、期待した静的ページそのものであることを確認する。
    # 見出しだけを比べると、別のページの一部が返っていても気付けない。
    def assert_page(locale)
      page = PAGES.fetch(locale)
      path = Rails.public_path.join(page)

      assert path.exist?, "#{page} が存在しない"
      assert_equal path.read, response.body, "#{page} 以外の内容が返っている"
    end
end
