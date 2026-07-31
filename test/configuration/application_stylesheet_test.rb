require "test_helper"

# アプリケーション全体のスタイル基盤の契約を検証する。
#
# 検証対象はデザイン変数の宣言と利用、および全画面へ効く最小規則の意味であり、
# CSS の全文、宣言の並び、個々の色や寸法の値そのものではない。
# 値を調整するたびにテストを書き換える構造にすると、テストが変更の抑止力ではなく
# 単なる作業になる。
class ApplicationStylesheetTest < ActiveSupport::TestCase
  STYLESHEET_PATH = Rails.root.join("app/assets/stylesheets/application.css")

  # 後続の Application Shell が前提にできるデザイン変数。
  # 用途で命名し、技術的な色名や採番は使わない。
  REQUIRED_TOKENS = %w[
    --font-family-sans
    --color-background
    --color-text
    --color-link
    --color-focus-ring
    --content-max-width
    --page-gutter
    --page-block-padding
    --content-gap
    --font-size-heading-1
    --line-height-body
    --line-height-heading
  ].freeze

  # 宣言の直前は規則の開始か直前の宣言の終端に限る。
  # var() による利用を宣言と取り違えないようにする。
  TOKEN_DECLARATION = /(?<=[{;])\s*(--[a-z0-9-]+)\s*:\s*([^;]+);/

  test "デザイン変数を :root へ一箇所で宣言する" do
    # 宣言箇所が分かれると、同じ変数の値がどちらで決まるかが読む順序に依存する。
    assert_equal 1, stylesheet_rules.count { |rule| rule.fetch(:selectors) == [ ":root" ] }
  end

  test "後続タスクが前提にするデザイン変数をすべて宣言する" do
    assert_empty REQUIRED_TOKENS - declared_tokens.keys
  end

  test "デザイン変数の値が空でない" do
    declared_tokens.each do |name, value|
      assert_not value.strip.empty?, "#{name} の値が空である"
    end
  end

  test "同じデザイン変数を二重に宣言しない" do
    duplicated = declared_token_names.tally.select { |_name, count| count > 1 }.keys

    assert_empty duplicated, "重複して宣言されたデザイン変数がある: #{duplicated.inspect}"
  end

  test "宣言したデザイン変数をすべて実際のスタイルから利用する" do
    # 利用されない変数は、値が妥当かどうかを画面から確認できない。
    unused = declared_tokens.keys.reject { |name| style_declarations.include?("var(#{name})") }

    assert_empty unused, "利用されていないデザイン変数がある: #{unused.inspect}"
  end

  test "Rails 生成時の manifest コメントだけの状態ではない" do
    assert_not_empty stylesheet_rules
  end

  test "すべての要素で幅の計算規則をそろえる" do
    assert_match(/box-sizing:\s*border-box/, declarations_for("*"))
  end

  test "ページ全体の背景・文字色・フォント・行間をデザイン変数から設定する" do
    page = declarations_for("html") + declarations_for("body")

    assert_includes page, "var(--color-background)"
    assert_includes page, "var(--color-text)"
    assert_includes page, "var(--font-family-sans)"
    assert_includes page, "var(--line-height-body)"
  end

  test "ブラウザー既定の body 余白を打ち消す" do
    assert_match(/margin:\s*0\s*;/, declarations_for("body"))
  end

  test "本文領域の最大幅と余白をデザイン変数から設定する" do
    main = declarations_for("main")

    assert_includes main, "var(--content-max-width)"
    assert_includes main, "var(--page-gutter)"
    assert_includes main, "var(--page-block-padding)"
  end

  test "見出しの寸法と余白をデザイン変数から設定する" do
    heading = declarations_for("h1")

    assert_includes heading, "var(--font-size-heading-1)"
    assert_includes heading, "var(--line-height-heading)"
    assert_includes heading, "var(--content-gap)"
  end

  test "キーボードフォーカスを可視化する" do
    focus = declarations_including(":focus-visible")

    assert_not_empty focus, ":focus-visible の規則がない"
    assert_includes focus, "var(--color-focus-ring)"
    assert_match(/outline:/, focus)
  end

  test "フォーカス表示を打ち消さない" do
    # outline を消すと、ポインターを使わない閲覧者が現在位置を追えなくなる。
    assert_no_match(/outline:\s*none/, style_source)
  end

  test "form control が本文のフォントを継承する" do
    %w[button input select textarea].each do |control|
      assert_match(/font:\s*inherit/, declarations_for(control), "#{control} がフォントを継承しない")
    end
  end

  test "画像と動画が親の幅を超えない" do
    %w[img picture svg video].each do |media|
      assert_match(/max-width:\s*100%/, declarations_for(media), "#{media} が親の幅を超え得る")
    end
  end

  test "幅を固定値で指定しない" do
    # 固定幅は狭い画面で横スクロールを生む。
    assert_no_match(/(?:min-|max-)?(?:width|inline-size):[^;]*\d+px/, style_source)
  end

  test "外部の資源を参照しない" do
    %w[@import @font-face url( http:// https://].each do |reference|
      assert_not_includes style_source, reference, "外部参照 #{reference} が含まれている"
    end
  end

  test "宣言の優先度を !important で上書きしない" do
    assert_not_includes style_source, "!important"
  end

  private
    # コメントを取り除いた CSS。
    # コメント内の記述を実装として誤認しないようにする。
    def style_source
      @style_source ||= File.read(STYLESHEET_PATH).gsub(%r{/\*.*?\*/}m, "")
    end

    # 規則を selector と宣言部へ分解する。
    # CSS nesting は使わない前提であり、規則は入れ子にならない。
    def stylesheet_rules
      @stylesheet_rules ||= style_source.scan(/([^{}]+)\{([^{}]*)\}/m).map do |selector, body|
        { selectors: selector.split(",").map(&:strip), body: body }
      end
    end

    def declared_tokens
      @declared_tokens ||= style_source.scan(TOKEN_DECLARATION).to_h
    end

    # 重複を検出するため、Hash へまとめる前の宣言順の名前を保持する。
    def declared_token_names
      @declared_token_names ||= style_source.scan(TOKEN_DECLARATION).map { |name, _value| name }
    end

    # :root を除いた宣言部。デザイン変数が実際に利用されているかを確認する。
    def style_declarations
      @style_declarations ||= stylesheet_rules
        .reject { |rule| rule.fetch(:selectors) == [ ":root" ] }
        .map { |rule| rule.fetch(:body) }
        .join("\n")
    end

    # 指定した selector をそのまま含む規則の宣言部。
    def declarations_for(selector)
      bodies_of { |selectors| selectors.include?(selector) }
    end

    # 指定した文字列を含む selector を持つ規則の宣言部。
    def declarations_including(fragment)
      bodies_of { |selectors| selectors.any? { |selector| selector.include?(fragment) } }
    end

    def bodies_of(&matcher)
      stylesheet_rules
        .select { |rule| matcher.call(rule.fetch(:selectors)) }
        .map { |rule| rule.fetch(:body) }
        .join("\n")
    end
end
