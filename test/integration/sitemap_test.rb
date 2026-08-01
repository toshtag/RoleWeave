require "test_helper"

# sitemap の契約を検証する。
#
# 検証対象は、検索エンジンへ渡す URL の集合である。
class SitemapTest < ActionDispatch::IntegrationTest
  setup do
    owner = User.create!(email_address: "owner@example.com", password: "correct horse battery")
    owner.confirm
    @organization = Organization.create_with_owner!(name: "Example Inc.", user: owner)
    @published = create_job_posting(status: "published", title: "公開中の求人")
  end

  test "XML として配信する" do
    get sitemap_path

    assert_response :success
    assert_match %r{\Aapplication/xml}, response.media_type.to_s + response.content_type.to_s
  end

  test "ロケールごとの入口と求人一覧を含む" do
    get sitemap_path

    I18n.available_locales.each do |locale|
      assert_includes response.body, localized_root_url(locale: locale)
      assert_includes response.body, public_job_postings_url(locale: locale)
    end
  end

  test "公開中の求人をロケールごとに含む" do
    get sitemap_path

    I18n.available_locales.each do |locale|
      assert_includes response.body, public_job_posting_url(locale: locale, id: @published)
    end
  end

  test "公開中でない求人を含まない" do
    (JobPosting::STATUSES - [ "published" ]).each do |status|
      job_posting = create_job_posting(status: status, title: "#{status} の求人")

      get sitemap_path

      assert_not_includes response.body, public_job_posting_url(locale: :ja, id: job_posting),
        "#{status} の求人が sitemap に含まれている"
    end
  end

  test "求人の更新日を含む" do
    get sitemap_path

    assert_includes response.body, "<lastmod>#{@published.updated_at.to_date.iso8601}</lastmod>"
  end

  test "解析できる XML を返す" do
    get sitemap_path

    document = Nokogiri::XML(response.body)

    assert_empty document.errors
    assert_operator document.css("url loc").size, :>=, 4
  end

  private
    def create_job_posting(status:, title:)
      @organization.job_postings.create!(status: status, title: title, description: "内容")
    end
end
