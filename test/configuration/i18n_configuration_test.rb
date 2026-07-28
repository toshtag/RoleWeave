require "test_helper"

# i18n 基盤の契約を検証する。
# 受け入れ条件の正本は design/acceptance/P0-T8-i18n-bootstrap.md とする。
#
# 検証対象はアプリケーションが所有する辞書と Rails の I18n 設定であり、
# rails-i18n と Rails 本体が提供する共通ロケールデータの内容そのものではない。
class I18nConfigurationTest < ActiveSupport::TestCase
  SUPPORTED_LOCALES = %i[ja en].freeze

  # アプリケーションが所有する辞書。共通ロケールデータはキー同型性の対象にしない。
  APPLICATION_LOCALE_FILES = {
    ja: Rails.root.join("config/locales/ja.yml"),
    en: Rails.root.join("config/locales/en.yml")
  }.freeze

  test "対応ロケールを日本語と英語だけに限定する" do
    # 宣言順への依存を避けるため、順序を持たない集合として比較する。
    assert_equal(
      SUPPORTED_LOCALES.to_set,
      I18n.available_locales.map(&:to_sym).to_set
    )
  end

  test "既定ロケールを日本語とする" do
    assert_equal :ja, I18n.default_locale
  end

  test "対応していないロケールを拒否する" do
    assert_raises(I18n::InvalidLocale) do
      I18n.with_locale(:fr) { nil }
    end
  end

  test "欠落した翻訳を別の言語で補わない" do
    # フォールバックが有効だと、英語の未翻訳が日本語のまま表示され、
    # 翻訳漏れが検出できなくなる。
    fallbacks_enabled = I18n.backend.class.ancestors.any? do |ancestor|
      ancestor.name == "I18n::Backend::Fallbacks"
    end

    assert_not fallbacks_enabled, "I18n のフォールバックが有効になっている"
  end

  test "日本語だけに存在する文言を英語で解決しない" do
    key = "i18n_configuration_test_fallback_probe"
    I18n.backend.store_translations(:ja, key => "日本語だけの文言")

    # raise: true を指定し、翻訳欠落の検出設定とは独立に振る舞いを確認する。
    assert_raises(I18n::MissingTranslationData) do
      I18n.t(key, locale: :en, raise: true)
    end
  ensure
    I18n.backend.reload!
  end

  test "test 環境で翻訳の欠落を例外として検出する" do
    assert_raises(I18n::MissingTranslationData) do
      I18n.t("i18n_configuration_test_missing_translation_probe")
    end
  end

  test "Rails 共通の日本語ロケールデータを利用できる" do
    # 内部実装クラスではなく公開 API を通して確認する。
    # 英語版と値が異なることまで確認しないと、
    # 日本語データが読み込まれていない状態を検出できない。
    assert_equal "%Y/%m/%d", I18n.t("date.formats.default", locale: :ja)

    japanese_blank = I18n.t("errors.messages.blank", locale: :ja)
    english_blank = I18n.t("errors.messages.blank", locale: :en)

    assert_not_equal english_blank, japanese_blank
  end

  test "アプリケーション名を日本語と英語の両方で提供する" do
    SUPPORTED_LOCALES.each do |locale|
      assert_equal "RoleWeave", I18n.t("application.name", locale: locale)
    end
  end

  test "アプリケーション辞書の葉キーが日本語と英語で一致する" do
    japanese_keys = leaf_entries(application_dictionary(:ja)).keys
    english_keys = leaf_entries(application_dictionary(:en)).keys

    assert_equal japanese_keys.sort, english_keys.sort
  end

  test "アプリケーション辞書の値が空でない文字列である" do
    SUPPORTED_LOCALES.each do |locale|
      leaf_entries(application_dictionary(locale)).each do |key, value|
        assert_kind_of String, value, "#{locale}.#{key} が文字列でない"
        assert_not value.strip.empty?, "#{locale}.#{key} が空である"
      end
    end
  end

  test "アプリケーション辞書に重複キーを持たない" do
    APPLICATION_LOCALE_FILES.each do |locale, path|
      duplicated = duplicated_mapping_keys(path)

      assert_empty duplicated, "#{locale} の辞書に重複キーがある: #{duplicated.inspect}"
    end
  end

  test "Rails 生成時のサンプル翻訳を残さない" do
    SUPPORTED_LOCALES.each do |locale|
      assert_not_includes(
        leaf_entries(application_dictionary(locale)).keys,
        "hello",
        "#{locale} の辞書に生成時のサンプルが残っている"
      )
    end
  end

  private
    # 辞書ファイルを解析し、ロケールルートの下の内容だけを返す。
    #
    # 辞書は信頼できる入力だが、alias とオブジェクト生成は許可しない。
    # 翻訳ファイルを実行経路にしない。
    def application_dictionary(locale)
      path = APPLICATION_LOCALE_FILES.fetch(locale)
      document = YAML.safe_load_file(path, aliases: false, permitted_classes: [])

      assert_kind_of Hash, document, "#{path} が mapping として解析できない"
      assert_equal [ locale.to_s ], document.keys, "#{path} のトップレベルロケールが想定外"

      document.fetch(locale.to_s)
    end

    # ネストした辞書を "a.b.c" 形式の葉キーへ平坦化する。
    # トップレベルキーの比較だけでは、下位のキー欠落を検出できない。
    def leaf_entries(node, prefix = [])
      return { prefix.join(".") => node } unless node.is_a?(Hash)

      node.reduce({}) do |entries, (key, value)|
        entries.merge(leaf_entries(value, prefix + [ key.to_s ]))
      end
    end

    # Psych は同じ mapping 内の重複キーを後勝ちで受理する。
    # 解析済みの Hash では重複が消えているため、解析木をたどって検出する。
    def duplicated_mapping_keys(path)
      mappings(Psych.parse_file(path)).flat_map do |mapping|
        keys = mapping.children.each_slice(2).map { |key, _value| key.value }
        keys.tally.select { |_key, count| count > 1 }.keys
      end
    end

    def mappings(node)
      found = node.is_a?(Psych::Nodes::Mapping) ? [ node ] : []
      found + node.children.to_a.flat_map { |child| mappings(child) }
    end
end
