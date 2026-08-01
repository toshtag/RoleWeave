require "test_helper"

# robots.txt の契約を検証する。
#
# 除外は「見えてはいけない」ための仕組みではない。
# ここで確かめるのは、巡回してほしくない経路を伝えられていることである。
class RobotsTest < ActionDispatch::IntegrationTest
  test "テキストとして配信する" do
    get robots_path

    assert_response :success
    assert_match %r{\Atext/plain}, response.media_type.to_s + response.content_type.to_s
  end

  test "sitemap の場所を示す" do
    get robots_path

    assert_includes response.body, "Sitemap: #{sitemap_url}"
  end

  test "ログインが要る画面をロケールごとに除外する" do
    get robots_path

    I18n.available_locales.each do |locale|
      %w[account organizations operator].each do |path|
        assert_includes response.body, "Disallow: /#{locale}/#{path}"
      end
    end
  end

  test "token を持つ経路を除外する" do
    get robots_path

    I18n.available_locales.each do |locale|
      %w[confirmation invitation password_reset].each do |path|
        assert_includes response.body, "Disallow: /#{locale}/#{path}"
      end
    end
  end

  test "公開求人の経路を除外しない" do
    get robots_path

    I18n.available_locales.each do |locale|
      assert_not_includes response.body, "Disallow: /#{locale}/jobs"
    end
  end

  test "静的な robots.txt を持たない" do
    # 静的ファイルが残ると、そちらが先に返る。
    assert_not Rails.public_path.join("robots.txt").exist?
  end
end
