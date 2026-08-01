require "test_helper"

# 全画面が共有する表示とキーボード操作の契約を検証する。
#
# 対象は動的画面（ロケール付きの入口）と静的エラー画面の両方とする。
# これまでの契約は、動的画面を見るテストと静的画面を見るテストへ分かれていた。
# 分かれていると、両方へ効くべき契約が片方にしか置かれず、
# もう片方だけが宣言を失っても、どのテストも失敗しない状態が生まれる。
#
# ここで検証するのは、画面の種類に依らず同じでなければならない事柄だけとする。
# 画面ごとに異なってよい文言・見出し・導線は、それぞれの画面のテストが持つ。
#
# 描画結果そのものは検証しない。崩れているかどうかは表示環境が決めるため、
# 自動検証では「崩れを引き起こす宣言の欠落」までを対象とする。
class SharedPageContractTest < ActionDispatch::IntegrationTest
  # 静的エラー画面と、その画面が名乗るべき言語。
  # 動的画面は I18n の設定から導く。ここへ言語を書き並べると、
  # 対応言語が増えたときに検証対象から漏れる画面ができる。
  STATIC_PAGES = {
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

  STYLESHEET_PATH = Rails.root.join("app/assets/stylesheets/application.css")

  # 静的エラー画面と application.css で値をそろえる主要デザイン変数。
  #
  # CSS の全文一致は求めない。静的エラー画面がアプリケーションの CSS を
  # 読み込まないことは ADR 0003 の決定であり、重複はその代償として受け入れている。
  # 一方、配色・書体・幅の基準まで分かれると、同じ製品の画面として見えなくなる。
  SHARED_TOKENS = %w[
    --font-family-sans
    --color-background
    --color-text
    --color-link
    --color-focus-ring
    --color-border
    --content-max-width
    --page-gutter
    --content-gap
  ].freeze

  # 宣言の直前は規則の開始か直前の宣言の終端に限る。
  # var() による利用を宣言と取り違えないようにする。
  TOKEN_DECLARATION = /(?<=[{;])\s*(--[a-z0-9-]+)\s*:\s*([^;]+);/

  # 要素型 selector としての body だけを取り出す。
  # class や id の一部に含まれる body を規則の開始と誤認しない。
  BODY_RULE = /(?<![\w.#-])body\s*\{([^{}]*)\}/m

  MIN_HEIGHT_DECLARATION = /(?:\A|;)\s*min-height\s*:\s*([^;]+)/

  # 画面の高さへ追従する単位と、それを解釈できない環境向けの基本値。
  DYNAMIC_VIEWPORT_HEIGHT = /\d\s*dvh\z/
  STATIC_VIEWPORT_HEIGHT = /\d\s*vh\z/

  # 拡大操作を妨げない下限。100% の 2 倍までは必ず拡大できる状態を保つ。
  MINIMUM_MAXIMUM_SCALE = 2

  # viewport の値は数値と単純なキーワードに限られる。
  VIEWPORT_NUMBER = /\A[+-]?(?:\d+(?:\.\d+)?|\.\d+)\z/

  # 拡大を禁止する user-scalable の値。0 と no のどちらも同じ意味になる。
  SCALING_DISABLED = %w[no 0 0.0].freeze

  test "全画面が表示領域の宣言を 1 件だけ持つ" do
    # 2 件あると、どちらが効くかが読み手にも解釈系にも一意に決まらない。
    each_page do |page, _locale, document|
      assert_select document, 'head meta[name="viewport"]', count: 1,
        message: "#{page} の viewport 宣言が 1 件でない"
    end
  end

  test "全画面が表示領域を端末の幅へ合わせる" do
    # width=device-width がないと、モバイルブラウザーは既定の仮想幅で描画し、
    # 画面全体を縮小して表示する。文字が読めない大きさになり、横スクロールも生まれる。
    each_page do |page, _locale, document|
      directives = viewport_directives(document)

      assert_equal "device-width", directives["width"], "#{page} の viewport が端末の幅を使わない"
      assert_equal "1", directives["initial-scale"], "#{page} の viewport の初期倍率が 1 でない"
    end
  end

  test "全画面で拡大操作を妨げない" do
    # 拡大を禁止すると、小さい文字を読むために拡大する閲覧者が内容へ到達できなくなる。
    each_page do |page, _locale, document|
      directives = viewport_directives(document)

      assert_not_includes SCALING_DISABLED, directives["user-scalable"],
        "#{page} が拡大操作を禁止している"

      maximum_scale = directives["maximum-scale"]
      next if maximum_scale.nil?

      assert_match VIEWPORT_NUMBER, maximum_scale, "#{page} の maximum-scale が数値でない"
      assert_operator maximum_scale.to_f, :>=, MINIMUM_MAXIMUM_SCALE,
        "#{page} の maximum-scale が拡大の下限を下回る"
    end
  end

  test "全画面が自身の言語を宣言する" do
    # html lang が実際の文言と食い違うと、読み上げの言語が本文と一致しない。
    each_page do |page, locale, document|
      assert_select document, "html[lang=?]", locale.to_s, count: 1,
        message: "#{page} の html lang が #{locale} でない"
    end
  end

  test "全画面が本文領域を 1 つだけ持つ" do
    # main が複数あると、支援技術が本文の開始位置を一意に決められない。
    each_page do |page, _locale, document|
      assert_select document, "main", count: 1, message: "#{page} の main が 1 件でない"
      assert_select document, "main main", count: 0, message: "#{page} の main が入れ子になっている"
    end
  end

  test "全画面が最上位の見出しを本文の中へ 1 つだけ持つ" do
    # h1 が複数あると、見出しから内容を把握する読み方で、画面の主題が定まらない。
    each_page do |page, _locale, document|
      assert_select document, "h1", count: 1, message: "#{page} の h1 が 1 件でない"
      assert_select document, "main h1", count: 1, message: "#{page} の h1 が本文の外にある"
    end
  end

  test "全画面の本文へキーボードで移動できる" do
    # 参照先が focusable でないと、画面はスクロールしてもフォーカスはリンクに残り、
    # 次の Tab がヘッダーへ戻る。読み飛ばしたはずの導線をもう一度たどることになる。
    each_page do |page, _locale, document|
      assert_select document, "a.skip-link[href=?]", "#main-content", count: 1,
        message: "#{page} にスキップリンクがない"
      assert_select document, "main#main-content[tabindex=?]", "-1", count: 1,
        message: "#{page} のスキップリンクの参照先がフォーカスを受け取れない"
    end
  end

  test "全画面が Tab の移動順序を組み替えない" do
    # 正の tabindex は、その要素を文書順より前へ引き上げる。
    # 一部だけを引き上げると、画面全体の移動順序が見た目の並びと一致しなくなる。
    each_page do |page, _locale, document|
      document.css("[tabindex]").each do |element|
        value = element["tabindex"]

        assert_match VIEWPORT_NUMBER, value, "#{page} の tabindex が数値でない: #{value}"
        assert_operator value.to_i, :<=, 0,
          "#{page} の #{element.name} が正の tabindex を持つ: #{value}"
      end
    end
  end

  test "全画面の高さ基準が可視領域へ追従する" do
    # モバイルブラウザーの 100vh は、アドレスバーを含めた最大の表示高さを指す。
    # 内容が短い画面では、続きが何もないままアドレスバーの高さぶんだけ縦スクロールが生まれる。
    #
    # dvh を解釈できない環境では上書きごと無視されるため、基本値を先に置く。
    each_stylesheet do |page, source|
      values = min_height_values(source)

      assert_operator values.size, :>=, 2, "#{page} の body に高さ基準の基本値がない"
      assert_match STATIC_VIEWPORT_HEIGHT, values.first, "#{page} の body の基本値が画面の高さでない"
      assert_match DYNAMIC_VIEWPORT_HEIGHT, values.last, "#{page} の body が可視領域へ追従しない"
    end
  end

  test "静的エラー画面が共通スタイルと同じデザイン変数を宣言する" do
    expected = shared_tokens(stylesheet_source)

    assert_equal SHARED_TOKENS.sort, expected.keys.sort,
      "application.css が主要デザイン変数を宣言していない"

    STATIC_PAGES.each_key do |page|
      assert_equal expected, shared_tokens(inline_style(page)),
        "#{page} のデザイン変数が application.css と一致しない"
    end
  end

  private
    # 動的画面と静的エラー画面を、同じ形で 1 つずつ渡す。
    # 呼び出し側が画面の種類を意識すると、片方だけへ契約を書く余地が残る。
    def each_page
      I18n.available_locales.each do |locale|
        dynamic_paths(locale).each do |path|
          get path

          assert_response :success

          yield path, locale, Nokogiri::HTML5(response.body)
        end
      end

      STATIC_PAGES.each do |page, locale|
        yield page, locale, Nokogiri::HTML5(page_source(page))
      end
    end

    # 未ログインで到達できる動的画面。
    # 画面が増えるたびにここへ加える。加え忘れると、その画面だけ契約から外れる。
    def dynamic_paths(locale)
      [
        localized_root_path(locale: locale),
        new_session_path(locale: locale),
        new_registration_path(locale: locale)
      ]
    end

    # 各画面へ実際に効いている CSS を渡す。
    # 動的画面は application.css を、静的エラー画面はインライン CSS を使う。
    def each_stylesheet
      yield STYLESHEET_PATH.basename.to_s, stylesheet_source

      STATIC_PAGES.each_key do |page|
        yield page, inline_style(page)
      end
    end

    def stylesheet_source
      declarations_only(STYLESHEET_PATH.read)
    end

    # コメントを取り除いた CSS。
    # コメント内の記述を宣言として誤認しないようにする。
    def declarations_only(source)
      source.gsub(%r{/\*.*?\*/}m, "")
    end

    def page_source(page)
      path = Rails.public_path.join(page)

      assert path.exist?, "#{page} が存在しない"

      path.read
    end

    def inline_style(page)
      declarations_only(Nokogiri::HTML5(page_source(page)).css("style").map(&:text).join("\n"))
    end

    # viewport の内容を、区切りの空白と英大文字小文字に依らない対応表へ変換する。
    def viewport_directives(document)
      content = document.at_css('head meta[name="viewport"]')&.[]("content").to_s

      content.downcase.split(",").filter_map do |directive|
        name, value = directive.split("=", 2)
        next if value.nil?

        [ name.strip, value.strip ]
      end.to_h
    end

    # body へ効く min-height を、宣言の現れる順に並べる。
    # 条件付きの上書きも対象へ含めるため、規則を 1 つへ絞らない。
    def min_height_values(source)
      rules = source.scan(BODY_RULE).flatten

      assert_not_empty rules, "body の規則が見つからない"

      rules.flat_map { |rule| rule.scan(MIN_HEIGHT_DECLARATION).flatten }.map(&:strip)
    end

    def shared_tokens(source)
      source.scan(TOKEN_DECLARATION)
            .to_h { |name, value| [ name, value.gsub(/\s+/, " ").strip ] }
            .slice(*SHARED_TOKENS)
    end
end
