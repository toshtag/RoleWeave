require "test_helper"

# 全画面が共有する HTML 構造の契約を検証する。
#
# 検証対象はランドマークの構成と、それらを結ぶ参照（スキップリンクの参照先、
# ブランドリンクの遷移先）であり、文言そのものや HTML の全文ではない。
#
# 逆に、構造を固定しすぎると後続タスクが正当な拡張をできなくなる。
# ヘッダーへ言語切替を足す P1-T4 を妨げないよう、
# 「この要素しか存在しない」という形の期待は置かない。
class ApplicationShellTest < ActionDispatch::IntegrationTest
  test "/ja が共通のランドマーク構造を持つ" do
    get "/ja"

    assert_response :success
    assert_shared_landmarks
  end

  test "/en が共通のランドマーク構造を持つ" do
    get "/en"

    assert_response :success
    assert_shared_landmarks
  end

  test "本文へ移動するリンクが共通の本文領域を指す" do
    # 参照先を文字列で期待値へ固定せず、応答の中で実際に解決できることを確認する。
    get "/ja"

    fragment = skip_link_fragment

    assert_select "main#{fragment}", count: 1, message: "スキップリンクの参照先が存在しない"
  end

  test "スキップリンクの参照先をプログラムからフォーカスできる" do
    # 参照先が focusable でないと、画面はスクロールしてもフォーカスはリンクに残る。
    # 次の Tab がヘッダーへ戻り、読み飛ばしたはずの導線をもう一度たどることになる。
    get "/ja"

    fragment = skip_link_fragment

    assert_select "main#{fragment}[tabindex=?]", "-1", count: 1
  end

  test "ヘッダーのブランドリンクが表示中のロケールの入口を指す" do
    # ブランドリンクが特定のロケールへ固定されていると、
    # 英語の閲覧者がヘッダーを押しただけで日本語へ落ちる。
    I18n.available_locales.each do |locale|
      get localized_root_path(locale: locale)

      assert_select(
        "header.site-header a.site-header__brand[href=?]",
        localized_root_path(locale: locale)
      )
    end
  end

  test "入口ページが本文領域を入れ子にしない" do
    # main が入れ子になると、支援技術が本文の開始位置を一意に決められない。
    get "/ja"

    assert_select "main", count: 1
    assert_select "main main", count: 0
  end

  test "共通のランドマークがスキップリンク・ヘッダー・本文・フッターの順に並ぶ" do
    # 順序だけを固定し、間に要素が増えること自体は妨げない。
    get "/ja"

    assert_equal %i[skip_link header main footer], landmark_sequence
  end

  test "スキップリンクの文言をリクエストのロケールで表示する" do
    # 片方の言語だけを確認すると、文言を直接書いた実装がもう片方で見逃される。
    each_locale do |locale, other_locale|
      assert_select "a.skip-link", text: skip_link_label(locale), count: 1
      assert_select "a.skip-link", text: skip_link_label(other_locale), count: 0
    end
  end

  test "フッターの説明をリクエストのロケールで表示する" do
    # 応答全体を探すと、フッターを空にして同じ文言を別の場所へ置いても通る。
    # 文言そのものではなく、フッターの中にあることを確認する。
    each_locale do |locale, other_locale|
      assert_select "footer.site-footer p", text: footer_description(locale), count: 1
      assert_select "footer.site-footer p", text: footer_description(other_locale), count: 0
    end
  end

  private
    # 対応ロケールの入口を順に取得し、そのロケールと他のロケールの組を渡す。
    # 対応言語が増えたときに、検証対象から漏れるロケールを作らない。
    def each_locale
      I18n.available_locales.each do |locale|
        get localized_root_path(locale: locale)

        (I18n.available_locales - [ locale ]).each do |other_locale|
          yield locale, other_locale
        end
      end
    end

    # 日英で共通して満たすべき構造。
    # 片方の言語にだけ存在するランドマークを作らないために、同じ期待を両方へ適用する。
    def assert_shared_landmarks
      assert_select "body > a.skip-link", count: 1
      assert_select "body > header.site-header", count: 1
      assert_select "body > main#main-content", count: 1
      assert_select "body > footer.site-footer", count: 1

      # ページ本文がレイアウトの外へこぼれていないことを、見出しの位置で確認する。
      assert_select "main#main-content h1"
    end

    def skip_link_fragment
      href = css_select("a.skip-link").first&.[]("href")

      assert href, "スキップリンクがない"
      assert href.start_with?("#"), "スキップリンクが同一ページ内を指していない: #{href}"

      href
    end

    # body 直下のランドマークだけを、現れた順に並べる。
    # 対象外の要素は無視し、将来の追加で順序の契約が壊れないようにする。
    def landmark_sequence
      landmarks = {
        "a.skip-link" => :skip_link,
        "header.site-header" => :header,
        "main#main-content" => :main,
        "footer.site-footer" => :footer
      }

      document_root_element.at("body").element_children.filter_map do |element|
        _selector, name = landmarks.find { |selector, _name| element.matches?(selector) }
        name
      end
    end

    # 表示文言そのものを検証する意図はないため、期待値は辞書から引く。
    def skip_link_label(locale)
      I18n.t("application.skip_to_content", locale: locale)
    end

    def footer_description(locale)
      I18n.t("application.footer.description", locale: locale)
    end
end
