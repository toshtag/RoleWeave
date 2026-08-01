require "test_helper"

# ActionController::InvalidAuthenticityToken を定義するファイル。
#
# この定数そのものは autoload の対象になっておらず、同じファイルにある
# ActionController::RequestForgeryProtection が読み込まれたときに付随して定義される。
# 明示的に読み込まないと、このテストだけを実行したときに解決できず、
# 実行するファイルの組み合わせで結果が変わる。
require "action_controller/metal/request_forgery_protection"

# エラー画面の契約を検証する。
#
# 検証対象は 2 つある。
#
# 1. 例外処理経路が、元の URL のロケールに対応する静的ページを返すこと
# 2. 静的ページ自体が、アプリケーションの描画経路から独立して成立していること
#
# エラー画面は Controller と View を経由しないため、通常の統合テストからは到達できない。
# ActionDispatch::ShowExceptions と設定済みの exceptions_app を組み合わせ、
# 実際の例外処理経路をそのまま通す。exceptions_app を直接呼ぶと、
# PATH_INFO の書き換えと original_path の保存という前提ごと検証から抜け落ちる。
#
# 検査対象は静的ファイルと Rack 応答であり、どちらも解析した節点を assert_select へ渡す。
# 応答が @response へ載る経路を通らないため、既定の検査対象には頼れない。
class ErrorPagesTest < ActionDispatch::IntegrationTest
  # 検査対象の静的ページと、そのページが名乗るべき言語。
  #
  # 日本語は既定ロケールであり、PublicExceptions のフォールバック先である
  # 拡張子なしのファイルを正本とする。404.ja.html は作らない。
  # 406 は exceptions_app を通らず、allow_browser の before_action が直接描画する。
  # 経路は異なるが静的ページとしての契約は同じであるため、ここでまとめて検査する。
  # 経路そのものは unsupported_browser_test が持つ。
  PAGES = {
    "400.html" => :ja,
    "400.en.html" => :en,
    "404.html" => :ja,
    "404.en.html" => :en,
    "406-unsupported-browser.html" => :ja,
    "406-unsupported-browser.en.html" => :en,
    "422.html" => :ja,
    "422.en.html" => :en,
    "500.html" => :ja,
    "500.en.html" => :en
  }.freeze

  # 静的ページの文言は辞書を持たないため、期待値をテストへ置く。
  # ここが文言と言語の唯一の対応表になる。文言を変えるときはこのテストも変える。
  HEADINGS = {
    "400" => { ja: "リクエストを処理できません", en: "Unable to process this request" },
    "404" => { ja: "ページが見つかりません", en: "Page not found" },
    "406" => { ja: "このブラウザーには対応していません", en: "Your browser is not supported" },
    "422" => { ja: "送信内容を受け付けられません", en: "Unable to accept this submission" },
    "500" => { ja: "ページを表示できません", en: "Unable to display this page" }
  }.freeze

  # 例外の詳細が応答へ混ざっていないことを、実際の例外メッセージで確認する。
  SENSITIVE_DETAIL = "SENSITIVE_TEST_EXCEPTION_DETAIL"

  # 各 status へ対応する例外。すべて機密情報に相当する文字列を持たせて発生させる。
  # 例外は 1 回の応答で使い切るため、生成する手続きを持つ。
  SENSITIVE_EXCEPTIONS = {
    400 => -> { ActionDispatch::Http::Parameters::ParseError.new(SENSITIVE_DETAIL) },
    404 => -> { ActionController::RoutingError.new(SENSITIVE_DETAIL) },
    422 => -> { ActionController::InvalidAuthenticityToken.new(SENSITIVE_DETAIL) },
    500 => -> { RuntimeError.new(SENSITIVE_DETAIL) }
  }.freeze

  test "エラー画面がページの言語を宣言する" do
    # html lang が実際の文言と食い違うと、読み上げの言語が本文と一致しない。
    each_page do |page, locale, document|
      assert_select document, "html[lang=?]", locale.to_s, count: 1, message: "#{page} の html lang が #{locale} でない"
    end
  end

  test "エラー画面が文字コードと表示領域を宣言する" do
    each_page do |page, _locale, document|
      assert_select document, "head meta[charset=?]", "utf-8", count: 1, message: "#{page} に charset がない"
      assert_select document, "head meta[name=?]", "viewport", count: 1, message: "#{page} に viewport がない"
    end
  end

  test "エラー画面を検索結果へ載せない" do
    # 存在しない URL やエラー状態の画面が検索結果へ現れると、
    # 閲覧者が入口だと思って開いた先がエラーになる。
    each_page do |page, _locale, document|
      assert_select document, "head meta[name=?][content=?]", "robots", "noindex, nofollow", count: 1,
        message: "#{page} が noindex, nofollow を持たない"
    end
  end

  test "エラー画面が状況を伝える表題を持つ" do
    each_page do |page, locale, document|
      assert_select document, "head title", count: 1, message: "#{page} に title がない"
      assert_select document, "main h1", text: heading(page, locale), count: 1,
        message: "#{page} の見出しが #{locale} の文言でない"
    end
  end

  test "エラー画面がもう一方の言語の文言を含まない" do
    # 日英を 1 ページへ併記すると、URL のロケールと表示言語が一致しなくなる。
    each_page do |page, locale, document|
      other_locales(locale).each do |other_locale|
        assert_not_includes document.text, heading(page, other_locale),
          "#{page} に #{other_locale} の見出しが混ざっている"
      end
    end
  end

  test "エラー画面が HTTP status code を閲覧者へ示す" do
    # 状況を問い合わせるときに、閲覧者が伝えられる手がかりを画面へ残す。
    each_page do |page, _locale, document|
      assert_select document, "main .error-page__status", text: status_code(page), count: 1,
        message: "#{page} に status code の表示がない"
    end
  end

  test "エラー画面が本文領域を 1 つだけ持つ" do
    each_page do |page, _locale, document|
      assert_select document, "main", count: 1, message: "#{page} の main が 1 件でない"
      assert_select document, "main h1", count: 1, message: "#{page} の h1 が 1 件でない"
    end
  end

  test "エラー画面の本文へキーボードで移動できる" do
    # 参照先が focusable でないと、画面はスクロールしてもフォーカスはリンクに残る。
    each_page do |page, _locale, document|
      assert_select document, "a.skip-link[href=?]", "#main-content", count: 1,
        message: "#{page} にスキップリンクがない"
      assert_select document, "main#main-content[tabindex=?]", "-1", count: 1,
        message: "#{page} のスキップリンクの参照先がフォーカスを受け取れない"
    end
  end

  test "エラー画面が表示中の言語の入口へ戻る導線を持つ" do
    # エラーの発生した URL しか出口がないと、閲覧者はそこから移動できない。
    each_page do |page, locale, document|
      assert_select document, "main a[href=?]", "/#{locale}", count: 1,
        message: "#{page} に #{locale} の入口へ戻る導線がない"
      assert_select document, "header a.site-header__brand[href=?]", "/#{locale}", count: 1,
        message: "#{page} のブランドリンクが #{locale} の入口を指していない"
    end
  end

  test "エラー画面が現在の表示言語をリンクではない要素で示す" do
    each_page do |page, locale, document|
      assert_select document, "header nav[aria-label]", count: 1, message: "#{page} に言語切替がない"
      assert_select document, "header nav [lang=?][aria-current=?]", locale.to_s, "page", count: 1,
        message: "#{page} が現在の表示言語を示していない"
      assert_select document, "header nav a[lang=?]", locale.to_s, count: 0,
        message: "#{page} で現在の言語がリンクになっている"
    end
  end

  test "エラー画面がもう一方の言語の入口へのリンクを持つ" do
    # 存在しない URL をもう一方の言語へ機械的に変換しても、その先も存在しない。
    # 別言語の導線は、その言語の入口へ向ける。
    each_page do |page, locale, document|
      other_locales(locale).each do |other_locale|
        assert_select document, "header nav a[href=?][lang=?][hreflang=?]",
          "/#{other_locale}", other_locale.to_s, other_locale.to_s, count: 1,
          message: "#{page} に #{other_locale} への導線がない"
      end
    end
  end

  test "エラー画面がアプリケーションのアセットへ依存しない" do
    # 500 は描画経路に障害がある状況で表示される。application.css や importmap を
    # 読み込むと、その障害がそのままエラー画面の表示不能につながる。
    each_page do |page, _locale, document|
      assert_select document, "script", count: 0, message: "#{page} が JavaScript を持つ"
      assert_select document, 'link[rel="stylesheet"]', count: 0, message: "#{page} が外部 CSS を読み込む"
      assert_select document, "img, picture, svg, video, iframe, object, embed", count: 0,
        message: "#{page} が埋め込みリソースを持つ"
      assert_select document, "head style", count: 1, message: "#{page} のスタイルが 1 件でない"
    end
  end

  test "エラー画面が外部への参照を持たない" do
    # 外部フォントや CDN を参照すると、表示が外部の到達性に依存する。
    each_page do |page, _locale, document|
      references(document).each do |reference|
        assert reference.start_with?("/", "#"),
          "#{page} が外部の参照を持つ: #{reference}"
      end
    end
  end

  test "すべてのエラー画面が同じスタイルを持つ" do
    # ページごとにスタイルが分岐すると、片方だけ崩れた状態を見落とす。
    # 静的ページはアプリケーションの CSS を読み込まないため、
    # 重複は意図したものである。詳細は ADR 0003 を参照する。
    styles = PAGES.keys.map { |page| document(page).css("style").map(&:text).join.strip }

    assert_equal 1, styles.uniq.size, "エラー画面のスタイルが一致しない"
  end

  test "解釈できない日本語 URL で日本語の 400 を返す" do
    response = exception_response(path: "/ja/broken", exception: parse_error, show_exceptions: :rescuable)

    assert_equal 400, response[:status]
    assert_html response
    assert_page "400.html", response
  end

  test "解釈できない英語 URL で英語の 400 を返す" do
    response = exception_response(path: "/en/broken", exception: parse_error, show_exceptions: :rescuable)

    assert_equal 400, response[:status]
    assert_html response
    assert_page "400.en.html", response
  end

  test "日本語 URL の送信内容を受け付けられないときに日本語の 422 を返す" do
    # 422 へ到達する経路（非 GET の route）はまだない。
    # 経路を追加するタスクでページを用意し忘れないよう、機構だけを先に固定する。
    response = exception_response(path: "/ja/rejected", exception: rejected_submission, show_exceptions: :rescuable)

    assert_equal 422, response[:status]
    assert_html response
    assert_page "422.html", response
  end

  test "英語 URL の送信内容を受け付けられないときに英語の 422 を返す" do
    response = exception_response(path: "/en/rejected", exception: rejected_submission, show_exceptions: :rescuable)

    assert_equal 422, response[:status]
    assert_html response
    assert_page "422.en.html", response
  end

  test "存在しない日本語 URL で日本語の 404 を返す" do
    response = exception_response(path: "/ja/missing", exception: routing_error, show_exceptions: :rescuable)

    assert_equal 404, response[:status]
    assert_html response
    assert_page "404.html", response
  end

  test "存在しない英語 URL で英語の 404 を返す" do
    response = exception_response(path: "/en/missing", exception: routing_error, show_exceptions: :rescuable)

    assert_equal 404, response[:status]
    assert_html response
    assert_page "404.en.html", response
  end

  test "対応していないロケールの URL で既定の言語の 404 を返す" do
    # 対応外のロケールを英語へ落とすと、日本語を既定とする設定と矛盾する。
    response = exception_response(path: "/fr/missing", exception: routing_error, show_exceptions: :rescuable)

    assert_equal 404, response[:status]
    assert_page "404.html", response
  end

  test "ロケールを持たない URL で既定の言語の 404 を返す" do
    response = exception_response(path: "/missing", exception: routing_error, show_exceptions: :rescuable)

    assert_equal 404, response[:status]
    assert_page "404.html", response
  end

  test "日本語 URL のサーバーエラーで日本語の 500 を返す" do
    response = exception_response(path: "/ja/failure", exception: server_error, show_exceptions: :all)

    assert_equal 500, response[:status]
    assert_html response
    assert_page "500.html", response
  end

  test "英語 URL のサーバーエラーで英語の 500 を返す" do
    response = exception_response(path: "/en/failure", exception: server_error, show_exceptions: :all)

    assert_equal 500, response[:status]
    assert_html response
    assert_page "500.en.html", response
  end

  test "ロケールを持たない URL のサーバーエラーで既定の言語の 500 を返す" do
    response = exception_response(path: "/failure", exception: server_error, show_exceptions: :all)

    assert_equal 500, response[:status]
    assert_page "500.html", response
  end

  test "エラー画面が例外の内容を閲覧者へ出さない" do
    # 例外メッセージや backtrace は、内部構造と入力値をそのまま外へ出す。
    # 静的ページを返す構成では起こり得ないが、動的な描画へ戻したときに検出する。
    #
    # 500 だけを見ると、他の status の画面へ混入した内容を見逃す。
    # 片方の言語だけを見ると、もう片方のページへ混入した内容を見逃す。
    SENSITIVE_EXCEPTIONS.each do |status, build_exception|
      PAGES.values.uniq.each do |locale|
        response = exception_response(path: "/#{locale}/failure", exception: build_exception.call, show_exceptions: :all)

        assert_equal status, response[:status]

        [ SENSITIVE_DETAIL, build_exception.call.class.name, "app/controllers" ].each do |detail|
          assert_not_includes response[:body], detail, "#{locale} の #{status} の画面へ #{detail} が出ている"
        end
      end
    end
  end

  private
    # 静的ページを 1 つずつ、その言語と解析結果とともに渡す。
    def each_page
      PAGES.each do |page, locale|
        yield page, locale, document(page)
      end
    end

    def other_locales(locale)
      PAGES.values.uniq - [ locale ]
    end

    def document(page)
      Nokogiri::HTML5(page_source(page))
    end

    def page_source(page)
      path = Rails.public_path.join(page)

      assert path.exist?, "#{page} が存在しない"

      path.read
    end

    # ファイル名の先頭にある数字を status code とする。
    # 406-unsupported-browser のように、status の後ろへ語が続くファイル名がある。
    def status_code(page)
      page[/\A\d+/]
    end

    def heading(page, locale)
      HEADINGS.fetch(status_code(page)).fetch(locale)
    end

    # ページが読み込む、または移動先とする URL。
    def references(document)
      document.css("[href], [src]").flat_map { |element| [ element["href"], element["src"] ] }.compact
    end

    # 例外処理経路を通した応答を返す。
    #
    # show_exceptions は例外の種類で使い分ける。RoutingError は rescue_responses へ
    # 登録された例外のため :rescuable で表示されるが、RuntimeError は :all を要する。
    def exception_response(path:, exception:, show_exceptions:)
      env = Rack::MockRequest.env_for(path, "HTTP_ACCEPT" => "text/html")
      env["action_dispatch.show_exceptions"] = show_exceptions
      env["action_dispatch.backtrace_cleaner"] = Rails.backtrace_cleaner

      application = ActionDispatch::ShowExceptions.new(
        ->(_env) { raise exception },
        Rails.application.config.exceptions_app
      )
      status, headers, body = application.call(env)
      content = body.each.to_a.join
      body.close if body.respond_to?(:close)

      { status: status, headers: headers, body: content }
    end

    def routing_error
      ActionController::RoutingError.new("No route matches")
    end

    # query string や本文を解釈できないときに起こる例外。rescue_responses で 400 へ対応する。
    def parse_error
      ActionDispatch::Http::Parameters::ParseError.new("invalid byte sequence")
    end

    # 送信内容を受け付けられないときに起こる例外。rescue_responses で 422 へ対応する。
    def rejected_submission
      ActionController::InvalidAuthenticityToken.new("Can't verify CSRF token authenticity")
    end

    def server_error
      RuntimeError.new(SENSITIVE_DETAIL)
    end

    # 応答が、期待した静的ページそのものであることを確認する。
    # 見出しだけを比べると、別のページの一部が返っていても気付けない。
    def assert_page(page, response)
      assert_equal page_source(page), response[:body], "#{page} 以外の内容が返っている"
    end

    def assert_html(response)
      assert_match %r{\Atext/html}, response[:headers][Rack::CONTENT_TYPE].to_s
    end
end
