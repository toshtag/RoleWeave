require "test_helper"

# ロケール付き入口 URL の契約を検証する。
#
# 検証対象は URL と表示言語の対応、および日英で共通する土台の読み込みであり、
# 入口ページの内容そのものではない。
class LocalizedHomeTest < ActionDispatch::IntegrationTest
  test "/ は既定ロケールの入口へ 302 で遷移する" do
    get "/"

    assert_equal 302, response.status
    assert_redirected_to "/ja"
  end

  test "/ で入口ページを描画しない" do
    # / と /ja の両方が同じ内容を返すと、日本語の入口 URL が 2 つになる。
    get "/"

    assert_not_includes response.body, summary(:ja)
  end

  test "Accept-Language が英語でも / は既定ロケールの入口へ遷移する" do
    get "/", headers: { "Accept-Language" => "en-US,en;q=0.9" }

    assert_redirected_to "/ja"
  end

  test "/ja で日本語の入口ページを表示する" do
    get "/ja"

    assert_response :success
    assert_select "html[lang=?]", "ja"
    assert_select "main h1", "RoleWeave"
    assert_includes response.body, summary(:ja)
    assert_not_includes response.body, summary(:en)
  end

  test "/en で英語の入口ページを表示する" do
    get "/en"

    assert_response :success
    assert_select "html[lang=?]", "en"
    assert_select "main h1", "RoleWeave"
    assert_includes response.body, summary(:en)
    assert_not_includes response.body, summary(:ja)
  end

  test "日英の入口ページが同じアプリケーションスタイルを読み込む" do
    # 言語ごとにスタイルが分かれると、片方だけ崩れた状態を見落とす。
    get "/ja"
    japanese_stylesheet = application_stylesheet_href

    get "/en"

    assert_equal japanese_stylesheet, application_stylesheet_href
  end

  test "直前のリクエストのロケールが次のリクエストへ漏れない" do
    get "/en"

    assert_includes response.body, summary(:en)

    get "/ja"

    assert_includes response.body, summary(:ja)
    assert_not_includes response.body, summary(:en)
  end

  test "リクエストの終了後に既定ロケールへ戻る" do
    get "/en"

    assert_equal I18n.default_locale, I18n.locale
  end

  test "対応していないロケールを route として受理しない" do
    # 例外表示の設定に依存しないよう、応答ではなく route の認識で確認する。
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/fr")
    end
  end

  test "大文字のロケールを route として受理しない" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/JA")
    end
  end

  test "ヘルスチェックをロケールなしで利用できる" do
    get "/up"

    assert_response :success
  end

  test "入口ページの URL helper がロケールごとのパスを生成する" do
    assert_equal "/ja", localized_root_path(locale: :ja)
    assert_equal "/en", localized_root_path(locale: :en)
  end

  private
    # 現在の応答が読み込んでいるアプリケーションの stylesheet を返す。
    #
    # digest 付きのファイル名を期待値へ固定しない。
    # また、CSS を正当に分割する余地を残すため、link の件数も断定しない。
    def application_stylesheet_href
      hrefs = css_select('link[rel="stylesheet"][data-turbo-track="reload"]').map do |link|
        link["href"]
      end
      href = hrefs.find { |value| File.basename(value).start_with?("application-") }

      assert href, "アプリケーションの stylesheet を読み込んでいない: #{hrefs.inspect}"

      href
    end

    # 表示文言そのものではなく、URL と表示言語の対応を検証するため、
    # 期待値は辞書から引く。文言を変更するたびにこのテストを書き換えない。
    def summary(locale)
      I18n.t("home.show.summary", locale: locale)
    end
end
