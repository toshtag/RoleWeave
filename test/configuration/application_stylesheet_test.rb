require "test_helper"

# アプリケーション全体のスタイル基盤の契約を検証する。
#
# 検証対象はデザイン変数の宣言と利用、および全画面へ効く最小規則の意味であり、
# CSS の全文、宣言の並び、個々の色や寸法の値そのものではない。
# 値を調整するたびにテストを書き換える構造にすると、テストが変更の抑止力ではなく
# 単なる作業になる。
#
# 逆に、検査範囲を広げすぎて正当な CSS まで拒否すると、
# 後続のタスクがテストを回避する方向へ進む。
# 禁止したいものは、全文検索ではなく対象を特定して表現する。
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
    --color-border
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

  DECLARATION = /(?:\A|;)\s*([-\w]+)\s*:\s*([^;]+)/

  # border 系 shorthand と longhand をまとめて取り出す。
  # どの辺へ線を引くかは見た目の調整に委ね、色の正本だけを固定するために使う。
  BORDER_DECLARATION = /(?:\A|;)\s*border[-\w]*\s*:\s*([^;]+)/

  LENGTH = /-?\d*\.?\d+[a-z%]*/

  # CSS のキーワードは大文字小文字を区別しない。
  # 検査もそれに合わせないと、表記を変えるだけで契約を迂回できる。
  NON_DRAWING_OUTLINE_STYLE = /\b(?:none|hidden)\b/i
  UNRENDERED_DISPLAY = /\Anone\z/i
  UNRENDERED_VISIBILITY = /\A(?:hidden|collapse)\z/i
  NO_TRANSFORM = /\Anone\z/i

  # CSS の数値表記。同じ値でも書き方は一通りではない。
  # ゼロの文字列表現を列挙すると、`.0` や `-0` のような表記で契約を迂回できる。
  # Ruby の Float() は先頭の小数点を受理せず 16 進表記を受理するため、
  # CSS 側の構文をここで決めてから数値へ変換する。
  CSS_NUMBER = /\A[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:e[+-]?\d+)?\z/i
  TRANSPARENT_COLOR = /\btransparent\b/i
  DISABLED_OUTLINE = /outline(?:-style)?:\s*(?:none|hidden)\b/i
  IMPORTANT_DECLARATION = /!\s*important\b/i

  # 全画面へ効くフォーカス表示の基準となる selector の形。
  GLOBAL_FOCUS_SELECTOR = /\A:where\((?<targets>.*)\):focus-visible\z/m

  # 基準が最低限そろえる対象。将来これを含む形で対象を増やすことは妨げない。
  REQUIRED_GLOBAL_FOCUS_TARGETS = %w[a button input select textarea].freeze

  # 現在の色は 16 進で表現している。CSS の色表現をすべて網羅するものではない。
  COLOR_LITERAL = /#[0-9a-f]{3,8}\b/i

  # 外部の stylesheet とフォントを読み込む at-rule。
  EXTERNAL_AT_RULE = /@(?:import|font-face)\b/i

  # url() の引数を引用符の有無に依らず取り出す。
  # CSS の URL 表記やエスケープをすべて解釈するものではない。
  URL_FUNCTION = /url\(\s*(?:(["'])(.*?)\1|([^)]*?))\s*\)/im

  # scheme 付きと scheme 相対の、外部ネットワークを指す URL。
  # 同一オリジンの相対・絶対パスと data URL は対象にしない。
  NETWORK_URL = %r{\A(?:(?:https?|ftp):)?//}i

  test "デザイン変数を :root へ一箇所で宣言する" do
    # 宣言箇所が分かれると、同じ変数の値がどちらで決まるかが読む順序に依存する。
    assert_equal 1, base_root_rules.size
  end

  test "後続タスクが前提にするデザイン変数をすべて :root へ宣言する" do
    assert_empty REQUIRED_TOKENS - base_root_tokens.keys
  end

  test "デザイン変数を :root の外で宣言しない" do
    # 利用箇所で宣言すると、その値が効く範囲が selector に依存し、共通の基準でなくなる。
    outside = token_declarations_in(other_rules).map { |name, _value| name }

    assert_empty outside.uniq, ":root 外で宣言されたデザイン変数がある: #{outside.uniq.inspect}"
  end

  test "条件付きの :root では基本値を持つデザイン変数だけを上書きする" do
    # @media などで値を切り替えること自体は認める。
    # ただし、条件を満たしたときだけ存在する変数は、基本値のない不完全な契約になる。
    names = token_declarations_in(conditional_root_rules).map { |name, _value| name }
    unknown = names.uniq - base_root_tokens.keys

    assert_empty unknown, "基本値を持たない条件付きデザイン変数がある: #{unknown.inspect}"
  end

  test "デザイン変数の値が空でない" do
    base_root_tokens.each do |name, value|
      assert_not value.strip.empty?, "#{name} の値が空である"
    end
  end

  test "同じ規則の中で同じデザイン変数を二重に宣言しない" do
    duplicated = stylesheet_rules.flat_map do |rule|
      names = token_declarations_in([ rule ]).map { |name, _value| name }
      names.tally.select { |_name, count| count > 1 }.keys
    end

    assert_empty duplicated.uniq, "重複して宣言されたデザイン変数がある: #{duplicated.uniq.inspect}"
  end

  test "宣言したデザイン変数をすべて実際のスタイルから利用する" do
    # 利用されない変数は、値が妥当かどうかを画面から確認できない。
    unused = base_root_tokens.keys.reject { |name| style_declarations.include?("var(#{name})") }

    assert_empty unused, "利用されていないデザイン変数がある: #{unused.inspect}"
  end

  test "16 進カラー値を :root の外へ直接記述しない" do
    # 色を利用箇所へ直接書くと、配色の正本が複数になる。
    # 検出できるのは 16 進表記だけであり、色表現全般を網羅するものではない。
    literals = style_declarations.scan(COLOR_LITERAL)

    assert_empty literals, ":root 外に直接記述された色がある: #{literals.inspect}"
  end

  test "Rails 生成時の manifest コメントだけの状態ではない" do
    assert_not_empty stylesheet_rules
  end

  test "すべての要素と擬似要素で幅の計算規則をそろえる" do
    # 擬似要素が対象から外れると、border や padding を持つ装飾だけ計算規則が変わる。
    %w[* *::before *::after].each do |selector|
      assert_match(
        /box-sizing:\s*border-box/,
        declarations_for(selector),
        "#{selector} が box-sizing の対象になっていない"
      )
    end
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

  test "本文領域が狭い画面でも親の幅を超えない" do
    # 固定幅の禁止は CSS 全体ではなく、ページコンテナである main へ限定する。
    # media query の条件は宣言ではないため、無条件の規則だけを対象にする。
    main = properties_for("main")

    assert_equal "100%", main["width"]
    assert_equal "var(--content-max-width)", main["max-width"]
    assert_nil main["min-width"], "main に固定の最小幅がある"
    assert_nil main["min-inline-size"], "main に固定の最小幅がある"
  end

  test "ページ全体を縦方向へ積む" do
    # 内容が短いページでフッターが本文の直後へ浮くと、
    # 画面下部の余白が「まだ続きがある」ように見える。
    body = properties_for("body")

    assert_equal "flex", body["display"]
    assert_equal "column", body["flex-direction"]
    assert_match(/100vh|100dvh/, body["min-height"].to_s, "body が画面の高さを満たさない")
  end

  test "本文領域が余った高さを引き受ける" do
    # 伸びるのを main へ限定する。ヘッダーとフッターが伸びると内容が中央から離れる。
    grow = properties_for("main").values_at("flex", "flex-grow").compact.first

    assert grow, "main が余った高さを引き受けない"
    assert_operator grow[LENGTH].to_f, :>, 0, "main の伸長係数が 0 である: #{grow}"
  end

  test "ヘッダーとフッターの内側が本文と同じ幅と左右余白を使う" do
    # 本文と基準が分かれると、画面幅を変えたときに三者の左端が揃わなくなる。
    %w[.site-header__inner .site-footer__inner].each do |selector|
      inner = properties_for(selector)

      assert_equal "100%", inner["width"], "#{selector} の幅が親に追従しない"
      assert_equal "var(--content-max-width)", inner["max-width"], "#{selector} の最大幅が本文と異なる"
      assert_equal "auto", inner["margin-inline"], "#{selector} が中央へ寄らない"
      assert_includes inner["padding-inline"].to_s, "var(--page-gutter)"
      assert_nil inner["min-width"], "#{selector} に固定の最小幅がある"
    end
  end

  test "ヘッダーとフッターの境界線の色をデザイン変数から設定する" do
    # 線を引く辺と太さは見た目の調整に委ね、色の正本だけを固定する。
    %w[.site-header .site-footer].each do |selector|
      borders = declarations_for(selector).scan(BORDER_DECLARATION).flatten

      assert_not_empty borders, "#{selector} に境界線の指定がない"
      borders.each do |value|
        assert_includes value, "var(--color-border)", "#{selector} の境界線が変数を使っていない: #{value}"
      end
    end
  end

  test "スキップリンクをフォーカスしたときに画面外への退避を解除する" do
    # 規則が存在するだけでは、フォーカス時に見えることを保証しない。
    # 同じ退避をフォーカス規則へ書き写しても、宣言は空にならず通過してしまう。
    resting = properties_for(".skip-link")
    focused = properties_for(".skip-link:focus-visible")

    assert resting["transform"], "通常時に画面外へ退避する指定がない"
    assert_no_match(NO_TRANSFORM, resting["transform"], "通常時に退避していない")
    assert_match(NO_TRANSFORM, focused["transform"].to_s, "フォーカスしても画面外のままである")
  end

  test "透明度のゼロ表現を数値として正規化する" do
    # 判定の根拠そのものを固定する。表記を変えるだけで契約を迂回できないようにする。
    %w[0 0.0 .0 -0 +0 00 0% 0.0% 0e0].each do |value|
      assert_predicate numeric_opacity(value), :zero?, "#{value} をゼロとして扱っていない"
    end

    assert_in_delta 0.5, numeric_opacity(".5")
    assert_in_delta 0.5, numeric_opacity("50%")
    assert_in_delta 1.0, numeric_opacity("1")
    assert_in_delta 1.0, numeric_opacity("100%")

    # 静的に値を確定できない指定は数値として扱わない。
    assert_nil numeric_opacity("calc(0)")
    assert_nil numeric_opacity("var(--skip-link-opacity)")
  end

  test "スキップリンクを透明なまま表示しない" do
    # 現在の実装は opacity を使っていない。使う形へ変えた場合に、
    # フォーカス時の戻し忘れだけを拒否する。
    resting_value = properties_for(".skip-link")["opacity"]

    return unless resting_value

    # 通常時が確実に見えている場合だけ、フォーカス時の指定を求めない。
    # ゼロ、負数、静的に確定できない値は、いずれも安全側で扱う。
    resting_opacity = numeric_opacity(resting_value)

    return if resting_opacity&.positive?

    focused_value = properties_for(".skip-link:focus-visible")["opacity"]

    assert focused_value, "フォーカス時に透明度を戻していない"

    focused_opacity = numeric_opacity(focused_value)

    assert focused_opacity, "フォーカス時の透明度を数値として検証できない: #{focused_value}"
    assert_operator focused_opacity, :>, 0, "フォーカス後もスキップリンクが透明である"
  end

  test "スキップリンクをフォーカスできない形で隠さない" do
    # display: none と visibility: hidden はフォーカス自体を受け取れなくする。
    # 画面外へ退避させる方法を指定はしないが、この 2 つによる非表示だけは拒否する。
    resting = properties_for(".skip-link")

    assert_no_match(UNRENDERED_DISPLAY, resting["display"].to_s, "スキップリンクが描画対象から外れている")
    assert_no_match(UNRENDERED_VISIBILITY, resting["visibility"].to_s, "スキップリンクが描画対象から外れている")
  end

  test "スキップリンクのフォーカス表示を打ち消さない" do
    focused = declarations_for(".skip-link:focus-visible")

    assert_no_match(DISABLED_OUTLINE, focused)
    assert_no_match(UNRENDERED_DISPLAY, properties_of(focused)["display"].to_s)
  end

  test "見出しの寸法と余白をデザイン変数から設定する" do
    heading = declarations_for("h1")

    assert_includes heading, "var(--font-size-heading-1)"
    assert_includes heading, "var(--line-height-heading)"
    assert_includes heading, "var(--content-gap)"
  end

  test "全画面で使うフォーカス表示の基準を一箇所で定義する" do
    # 固定するのは全画面へ効く基準の数であり、:focus-visible 規則の総数ではない。
    # 部品ごとにフォーカス時の見え方を足すことは、この契約の対象にしない。
    assert_equal 1, global_focus_rules.size
  end

  test "フォーカスのアウトラインが描画される幅・線種・色を持つ" do
    # 規則が存在するだけでは見えることを保証しない。
    # 0 幅、描画されない線種、透明色への退行を拒否する。
    outline = global_focus_properties["outline"]

    assert outline, "フォーカスの基準に outline の指定がない"
    assert_positive_length outline, "outline"
    assert_no_match(NON_DRAWING_OUTLINE_STYLE, outline, "outline の線種が描画されない: #{outline}")
    assert_no_match(TRANSPARENT_COLOR, outline, "outline の色が透明である: #{outline}")
    assert_includes(
      outline,
      "var(--color-focus-ring)",
      "outline 自体の色にデザイン変数を使っていない: #{outline}"
    )
  end

  test "フォーカスのアウトラインを longhand で打ち消さない" do
    # shorthand の後ろに longhand を置くと、shorthand の値を無効化できる。
    width = global_focus_properties["outline-width"]
    style = global_focus_properties["outline-style"]
    color = global_focus_properties["outline-color"]

    assert_positive_length(width, "outline-width") if width

    if style
      assert_no_match(NON_DRAWING_OUTLINE_STYLE, style, "outline-style が描画されない: #{style}")
    end

    if color
      assert_no_match(TRANSPARENT_COLOR, color, "outline-color が透明である: #{color}")
      assert_includes(
        color,
        "var(--color-focus-ring)",
        "outline-color にデザイン変数を使っていない: #{color}"
      )
    end
  end

  test "フォーカス表示を打ち消さない" do
    # outline を消すと、ポインターを使わない閲覧者が現在位置を追えなくなる。
    assert_no_match(DISABLED_OUTLINE, style_source)
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

  test "外部の資源を読み込む at-rule を使わない" do
    assert_no_match(EXTERNAL_AT_RULE, style_source)
  end

  test "外部ネットワーク上の資源を参照しない" do
    # 同一オリジンの url() は将来の正当な利用があり得るため禁止しない。
    # 引用符の有無、前後の空白、大文字小文字に依らず、外部への参照だけを拒否する。
    external = stylesheet_urls.select { |url| url.match?(NETWORK_URL) }

    assert_empty external, "外部ネットワークへの参照がある: #{external.inspect}"
  end

  test "宣言の優先度を important で上書きしない" do
    assert_no_match(IMPORTANT_DECLARATION, style_source)
  end

  private
    # opacity の値を 0.0〜1.0 の数値へ正規化する。
    # 百分率は同じ意味の別表記であり、数値と同じ土俵で比べられるようにする。
    # 静的に確定できない値（calc や var）は nil を返し、呼び出し側で安全側へ倒す。
    def numeric_opacity(value)
      source = value.to_s.strip
      percentage = source.end_with?("%")
      number = percentage ? source.delete_suffix("%") : source

      return nil unless number.match?(CSS_NUMBER)

      percentage ? number.to_f / 100.0 : number.to_f
    end

    def assert_positive_length(value, label)
      length = value[LENGTH]

      assert length, "#{label} に幅の指定がない: #{value}"
      assert_operator length.to_f, :>, 0, "#{label} が 0 で、フォーカスが見えない: #{value}"
    end

    # コメントを取り除いた CSS。
    # コメント内の記述を実装として誤認しないようにする。
    def style_source
      @style_source ||= File.read(STYLESHEET_PATH).gsub(%r{/\*.*?\*/}m, "")
    end

    def stylesheet_rules
      @stylesheet_rules ||= parse_rules(style_source, conditional: false)
    end

    # CSS を規則の一覧へ分解する。
    #
    # 括弧の対応だけを見る最小の実装であり、CSS の完全な構文解析ではない。
    # @media などの条件付き規則は、その中身を conditional として区別する。
    # 条件付きの宣言を無条件の契約と同じ位置で扱うと、
    # 正当なレスポンシブ指定が固定値の指定として誤検出される。
    def parse_rules(source, conditional:)
      rules = []
      prelude = +""
      body = +""
      depth = 0

      source.each_char do |character|
        if depth.zero?
          character == "{" ? depth = 1 : prelude << character
          next
        end

        depth += 1 if character == "{"
        depth -= 1 if character == "}"

        if depth.zero?
          rules.concat(build_rules(prelude, body, conditional))
          prelude = +""
          body = +""
        else
          body << character
        end
      end

      rules
    end

    def build_rules(prelude, body, conditional)
      selector = prelude.strip

      return parse_rules(body, conditional: true) if selector.start_with?("@")

      [ { selectors: split_selector_list(selector), body: body, conditional: conditional } ]
    end

    # selector 一覧をカンマで分割する。
    #
    # :where(a, button) のような関数型擬似クラスや属性値の中のカンマでは分割しない。
    # 単純な split(",") では :where(a, button):focus-visible が
    # 存在しない単独 selector へ分解され、無関係な規則を取り違える。
    def split_selector_list(source)
      selectors = []
      current = +""
      parentheses = 0
      brackets = 0
      quote = nil
      escaped = false

      source.each_char do |character|
        if escaped
          escaped = false
        elsif quote
          quote = nil if character == quote
          escaped = true if character == "\\"
        else
          case character
          when "\\" then escaped = true
          when '"', "'" then quote = character
          when "(" then parentheses += 1
          when ")" then parentheses -= 1
          when "[" then brackets += 1
          when "]" then brackets -= 1
          when ","
            if parentheses.zero? && brackets.zero?
              selectors << current
              current = +""
              next
            end
          end
        end

        current << character
      end

      selectors << current

      validate_selector_list(source, selectors, parentheses, brackets, quote)
    end

    def validate_selector_list(source, selectors, parentheses, brackets, quote)
      unless parentheses.zero? && brackets.zero? && quote.nil?
        raise "selector の括弧または引用符が対応していない: #{source.inspect}"
      end

      stripped = selectors.map(&:strip)

      raise "空の selector がある: #{source.inspect}" if stripped.any?(&:empty?)

      stripped
    end

    def base_root_rules
      @base_root_rules ||= root_rules.reject { |rule| rule.fetch(:conditional) }
    end

    def conditional_root_rules
      @conditional_root_rules ||= root_rules.select { |rule| rule.fetch(:conditional) }
    end

    def root_rules
      @root_rules ||= stylesheet_rules.select { |rule| rule.fetch(:selectors) == [ ":root" ] }
    end

    def other_rules
      @other_rules ||= stylesheet_rules - root_rules
    end

    # 無条件に適用される規則。media query の中身は含めない。
    def unconditional_rules
      @unconditional_rules ||= stylesheet_rules.reject { |rule| rule.fetch(:conditional) }
    end

    def base_root_tokens
      @base_root_tokens ||= token_declarations_in(base_root_rules).to_h
    end

    # 規則の宣言部からデザイン変数の宣言を取り出す。
    # 先頭の宣言も検出できるよう、宣言部の直前に規則の開始を補う。
    def token_declarations_in(rules)
      rules.flat_map { |rule| "{#{rule.fetch(:body)}".scan(TOKEN_DECLARATION) }
    end

    # :root を除く宣言部。デザイン変数の利用と、色の直書きを確認する。
    def style_declarations
      @style_declarations ||= join_bodies(other_rules)
    end

    # url() の引数を取り出す。
    def stylesheet_urls
      style_source.scan(URL_FUNCTION).map do |_quote, quoted, unquoted|
        (quoted || unquoted).to_s.strip
      end
    end

    # 全画面へ効くフォーカス表示の基準となる規則。
    #
    # :focus-visible を持つ規則をすべて集めると、部品ごとのフォーカス時の見え方まで
    # 基準の一部として扱ってしまう。必須の対象をすべて含む :where() の規則だけを基準とする。
    def global_focus_rules
      @global_focus_rules ||= unconditional_rules.select do |rule|
        rule.fetch(:selectors).any? { |selector| global_focus_basis?(selector) }
      end
    end

    def global_focus_basis?(selector)
      match = GLOBAL_FOCUS_SELECTOR.match(selector)

      return false unless match

      (REQUIRED_GLOBAL_FOCUS_TARGETS - split_selector_list(match[:targets])).empty?
    end

    def global_focus_properties
      @global_focus_properties ||= begin
        assert_equal 1, global_focus_rules.size, "フォーカス表示の基準が一意でない"

        properties_of(global_focus_rules.fetch(0).fetch(:body))
      end
    end

    # 指定した selector をそのまま含む、無条件の規則の宣言部。
    def declarations_for(selector)
      join_bodies(unconditional_rules.select { |rule| rule.fetch(:selectors).include?(selector) })
    end

    def join_bodies(rules)
      rules.map { |rule| rule.fetch(:body) }.join(";\n")
    end

    def properties_for(selector)
      properties_of(declarations_for(selector))
    end

    # 宣言部を property => value として取り出す最小の helper。
    # 値の内容まで検査したい少数の契約にだけ使い、CSS 全体の解析は担わせない。
    def properties_of(declarations)
      entries = declarations.scan(DECLARATION).map { |property, value| [ property, value.strip ] }
      duplicated = entries.map(&:first).tally.select { |_property, count| count > 1 }.keys

      # 後勝ちで黙って上書きすると、どちらが効くかをテストが誤って判断する。
      assert_empty duplicated, "同じプロパティが重複して宣言されている: #{duplicated.inspect}"

      entries.to_h
    end
end
