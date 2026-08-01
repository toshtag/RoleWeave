require "test_helper"

# ヘッダーの言語切替の契約を検証する。
#
# 検証対象は、現在の表示言語の示し方と、他の言語へ移動する導線の構造・遷移先であり、
# 表示順や見た目ではない。
#
# 対応言語は I18n.available_locales を正本とする。日本語と英語をテストへ直接書くと、
# 対応言語が増えたときに、切替へ現れない言語ができても検出できない。
class LanguageSwitcherTest < ActionDispatch::IntegrationTest
  SWITCHER = "header.site-header nav.language-switcher".freeze
  CURRENT = "#{SWITCHER} span.language-switcher__current".freeze
  LINK = "#{SWITCHER} a.language-switcher__link".freeze

  test "対応するすべてのロケールの入口に言語切替がある" do
    # 片方の言語にだけ切替があると、そこへ入った閲覧者は URL を書き換えるしかなくなる。
    each_locale do |locale|
      assert_select SWITCHER, count: 1, message: "#{locale} の入口に言語切替がない"
    end
  end

  test "言語切替が対応するすべての言語を選択肢として持つ" do
    # 選択肢の数だけでなく中身も確認する。日本語と英語を直接書いた実装は、
    # 対応言語が増えたときにここで検出される。
    each_locale do |locale|
      assert_select "#{SWITCHER} ul > li", count: I18n.available_locales.size

      assert_equal(
        I18n.available_locales.map(&:to_s).to_set,
        offered_locales,
        "#{locale} の言語切替が対応言語をすべて提供していない"
      )
    end
  end

  test "言語切替の名前をリクエストのロケールで表示する" do
    # ナビゲーションが複数になったとき、名前がないと支援技術はどれが何かを区別できない。
    # 名前を直接書いた実装は、もう片方の言語で誤った表記のまま残る。
    each_locale do |locale, other_locale|
      assert_select "#{SWITCHER}[aria-label=?]", switcher_label(locale), count: 1
      assert_select "#{SWITCHER}[aria-label=?]", switcher_label(other_locale), count: 0
    end
  end

  test "現在の表示言語をリンクではない要素で示す" do
    # 現在地への自己リンクは、キーボード操作でたどっても何も起きない導線になる。
    each_locale do |locale|
      assert_select CURRENT, count: 1
      assert_select "#{CURRENT}[lang=?]", locale.to_s, text: language_name(locale), count: 1
      assert_select "#{LINK}[lang=?]", locale.to_s, count: 0, message: "現在の言語がリンクになっている"
    end
  end

  test "現在の表示言語に aria-current を与える" do
    # 太字だけで示すと、その区別は画面を見ている閲覧者にしか届かない。
    each_locale do |locale|
      assert_select "#{CURRENT}[aria-current=?]", "page", count: 1,
        message: "#{locale} の現在の言語が状態を伝えていない"
    end
  end

  test "現在の表示言語以外を入口へのリンクとして示す" do
    # 遷移先は route helper で生成した URL と一致させ、文字列の組み立てを許さない。
    each_locale do |locale, other_locale|
      assert_select(
        "#{LINK}[href=?][lang=?][hreflang=?]",
        localized_root_path(locale: other_locale),
        other_locale.to_s,
        other_locale.to_s,
        text: language_name(other_locale),
        count: 1
      )
    end
  end

  test "現在の表示言語以外へ aria-current を与えない" do
    # 現在地が複数あると、支援技術は現在の表示言語を一意に伝えられない。
    each_locale do |locale|
      assert_select "#{LINK}[aria-current]", count: 0,
        message: "#{locale} の画面で現在地が複数ある"
    end
  end

  test "言語名をどのロケールでも自称表記で表示する" do
    # 翻訳先の言語で言語名を訳すと、その言語を読めない閲覧者が自分の言語を見つけられない。
    locale_pairs.each do |locale, other_locale|
      assert_equal(
        language_name(locale),
        I18n.t("application.language_switcher.languages.#{locale}", locale: other_locale)
      )
    end
  end

  test "言語切替のリンクをたどると URL と表示言語が切り替わる" do
    # 構造だけを確認すると、リンク先が正しくても遷移後の表示が変わらない実装を見逃す。
    # 遷移のたびに入口を取り直し、直前の応答を引きずらないようにする。
    locale_pairs.each do |locale, other_locale|
      get localized_root_path(locale: locale)

      destination = css_select("#{LINK}[lang=\"#{other_locale}\"]").first&.[]("href")

      assert destination, "#{locale} の画面に #{other_locale} へのリンクがない"

      get destination

      assert_response :success
      assert_equal destination, request.path
      assert_select "html[lang=?]", other_locale.to_s
      assert_includes response.body, summary(other_locale)
      assert_not_includes response.body, summary(locale)
      assert_select "#{CURRENT}[lang=?][aria-current=?]", other_locale.to_s, "page", count: 1
    end
  end

  private
    # 対応ロケールの入口を順に取得し、そのロケールと他のロケールの組を渡す。
    # 対応言語が増えたときに、検証対象から漏れるロケールを作らない。
    def each_locale
      I18n.available_locales.each do |locale|
        get localized_root_path(locale: locale)

        assert_response :success

        (I18n.available_locales - [ locale ]).each do |other_locale|
          yield locale, other_locale
        end
      end
    end

    # 表示中のロケールと、そこから移動できるはずのロケールの組。
    def locale_pairs
      I18n.available_locales.flat_map do |locale|
        (I18n.available_locales - [ locale ]).map { |other_locale| [ locale, other_locale ] }
      end
    end

    # 言語切替が提供している言語。現在の言語とリンクの両方を対象にする。
    def offered_locales
      css_select("#{CURRENT}, #{LINK}").filter_map { |element| element["lang"] }.to_set
    end

    # 表示文言そのものを検証する意図はないため、期待値は辞書から引く。
    def switcher_label(locale)
      I18n.t("application.language_switcher.label", locale: locale)
    end

    def language_name(locale)
      I18n.t("application.language_switcher.languages.#{locale}", locale: locale)
    end

    def summary(locale)
      I18n.t("home.show.summary", locale: locale)
    end
end
