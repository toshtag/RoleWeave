require "test_helper"

# 公開側の求人の一覧と詳細の契約を検証する。
#
# 検証対象は「何が公開側から見えるか」であり、組織側の管理画面ではない。
class PublicJobPostingsTest < ActionDispatch::IntegrationTest
  setup do
    owner = User.create!(email_address: "owner@example.com", password: "correct horse battery")
    owner.confirm
    @organization = Organization.create_with_owner!(name: "Example Inc.", user: owner)

    @published = create_job_posting(status: "published", title: "公開中の求人")
  end

  test "ログインなしで一覧を表示できる" do
    get public_job_postings_path(locale: :ja)

    assert_response :success
    assert_select "main a", text: @published.title
  end

  test "公開中でない求人は一覧に出ない" do
    (JobPosting::STATUSES - [ "published" ]).each do |status|
      create_job_posting(status: status, title: "#{status} の求人")
    end

    get public_job_postings_path(locale: :ja)

    (JobPosting::STATUSES - [ "published" ]).each do |status|
      assert_select "main", text: /#{status} の求人/, count: 0
    end
  end

  test "ログインなしで詳細を表示できる" do
    get public_job_posting_path(locale: :ja, id: @published)

    assert_response :success
    assert_select "main h1", text: @published.title
    assert_select "main", text: /#{Regexp.escape(@organization.name)}/
  end

  test "公開中でない求人の詳細は 404 になる" do
    # 分けると、審査中の求人があることだけが分かる。
    (JobPosting::STATUSES - [ "published" ]).each do |status|
      job_posting = create_job_posting(status: status, title: "#{status} の求人")

      get public_job_posting_path(locale: :ja, id: job_posting)

      assert_response :not_found, "#{status} の求人が公開側から見える"
    end
  end

  test "存在しない求人の詳細は 404 になる" do
    get public_job_posting_path(locale: :ja, id: 0)

    assert_response :not_found
  end

  test "求人がないときにその旨を伝える" do
    @published.update_column(:status, "draft")

    get public_job_postings_path(locale: :ja)

    assert_response :success
    assert_select "main p", text: I18n.t("public.job_postings.index.empty")
  end

  test "一覧と詳細が canonical URL を出力する" do
    get public_job_postings_path(locale: :ja)

    assert_select "head link[rel=?][href=?]", "canonical", public_job_postings_url(locale: :ja), count: 1

    get public_job_posting_path(locale: :ja, id: @published)

    assert_select "head link[rel=?][href=?]", "canonical",
      public_job_posting_url(locale: :ja, id: @published), count: 1
  end

  test "他の画面には canonical を出さない" do
    get localized_root_path(locale: :ja)

    assert_select "head link[rel=?]", "canonical", count: 0
  end

  test "詳細に入力した項目が出る" do
    @published.update!(location: "東京", occupation: "人事", employment_type: "full_time", salary: "年収 500 万円")

    get public_job_posting_path(locale: :ja, id: @published)

    assert_select "main dd", text: "東京"
    assert_select "main dd", text: I18n.t("job_postings.employment_types.full_time")
  end

  test "一覧と詳細を日本語と英語で表示する" do
    I18n.available_locales.each do |locale|
      get public_job_postings_path(locale: locale)

      assert_response :success
      assert_select "main h1", text: I18n.t("public.job_postings.index.title", locale: locale)

      get public_job_posting_path(locale: locale, id: @published)

      assert_response :success
      assert_select "html[lang=?]", locale.to_s
    end
  end

  test "入口ページから求人の一覧へたどれる" do
    get localized_root_path(locale: :ja)

    assert_select "main a[href=?]", public_job_postings_path(locale: :ja)
  end

  test "キーワードで絞り込める" do
    other = create_job_posting(status: "published", title: "Backend Engineer")

    get public_job_postings_path(locale: :ja, keyword: "Backend")

    assert_select "main a", text: other.title
    assert_select "main a", text: @published.title, count: 0
  end

  test "条件を組み合わせて絞り込める" do
    @published.update!(location: "東京", employment_type: "full_time")
    create_job_posting(status: "published", title: "大阪の求人").update!(location: "大阪")

    get public_job_postings_path(locale: :ja, location: "東京", employment_type: "full_time")

    assert_select "main a", text: @published.title
    assert_select "main a", text: "大阪の求人", count: 0
  end

  test "条件に一致しないときはその旨を伝える" do
    get public_job_postings_path(locale: :ja, keyword: "一致しない語")

    assert_response :success
    assert_select "main p", text: I18n.t("public.job_postings.index.no_results")
  end

  test "絞り込んでも公開中でない求人は出ない" do
    create_job_posting(status: "draft", title: "下書きの求人")

    get public_job_postings_path(locale: :ja, keyword: "求人")

    assert_select "main", text: /下書きの求人/, count: 0
  end

  test "空の条件はすべての公開求人を返す" do
    get public_job_postings_path(locale: :ja, keyword: "", location: "")

    assert_select "main a", text: @published.title
  end

  test "条件を持つ一覧の canonical が条件を持たない一覧になる" do
    # 同じ求人の集合へ無数の URL から到達できる状態を、検索エンジンへ渡さない。
    get public_job_postings_path(locale: :ja, keyword: "採用")

    assert_select "head link[rel=?][href=?]", "canonical", public_job_postings_url(locale: :ja), count: 1
  end

  test "条件を持つ一覧を索引させない" do
    get public_job_postings_path(locale: :ja, keyword: "採用")

    assert_select "head meta[name=?][content=?]", "robots", "noindex, follow", count: 1
  end

  test "条件を持たない一覧は索引させる" do
    get public_job_postings_path(locale: :ja)

    assert_select "head meta[name=?]", "robots", count: 0
  end

  test "絞り込みの入力欄を日本語と英語で表示する" do
    I18n.available_locales.each do |locale|
      get public_job_postings_path(locale: locale)

      assert_select "form label", text: I18n.t("public.job_postings.index.keyword", locale: locale)
      assert_select "form input[name=?]", "keyword"
      assert_select "form select[name=?]", "employment_type"
    end
  end

  private
    def create_job_posting(status:, title:)
      @organization.job_postings.create!(status: status, title: title, description: "内容")
    end
end
