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

  test "通貨と最低年収で絞り込める" do
    @published.update!(salary_currency: "JPY", annual_salary_min: 5_000_000)
    high = create_job_posting(status: "published", title: "高い求人")
    high.update!(salary_currency: "JPY", annual_salary_min: 9_000_000)

    get public_job_postings_path(locale: :ja, salary_currency: "JPY", minimum_salary: 8_000_000)

    assert_select "main a", text: high.title
    assert_select "main a", text: @published.title, count: 0
  end

  test "金額を持たない求人は金額の条件で出ない" do
    get public_job_postings_path(locale: :ja, salary_currency: "JPY", minimum_salary: 1_000)

    assert_select "main a", text: @published.title, count: 0
  end

  test "詳細に構造化された給与が出る" do
    @published.update!(salary_currency: "JPY", annual_salary_min: 5_000_000, annual_salary_max: 7_000_000)

    get public_job_posting_path(locale: :ja, id: @published)

    assert_select "main dd", text: /5,000,000/
    assert_select "main dd", text: /7,000,000/
  end

  test "下限だけの求人でも読める形で出る" do
    @published.update!(salary_currency: "JPY", annual_salary_min: 5_000_000)

    get public_job_posting_path(locale: :ja, id: @published)

    assert_select "main dd", text: /#{Regexp.escape(I18n.t("job_postings.salary_from", amount: "5,000,000"))}/
  end

  test "給与の絞り込みの入力欄を日本語と英語で表示する" do
    I18n.available_locales.each do |locale|
      get public_job_postings_path(locale: locale)

      assert_select "form label", text: I18n.t("public.job_postings.index.minimum_salary", locale: locale)
      assert_select "form select[name=?]", "salary_currency"
    end
  end

  test "1 ページに件数分までしか出ない" do
    Pagination::DEFAULT_PER_PAGE.times { |index| create_job_posting(status: "published", title: "追加 #{index}") }

    get public_job_postings_path(locale: :ja)

    assert_select "main ul.job-posting-list li", count: Pagination::DEFAULT_PER_PAGE
  end

  test "次のページに続きが出る" do
    Pagination::DEFAULT_PER_PAGE.times { |index| create_job_posting(status: "published", title: "追加 #{index}") }

    get public_job_postings_path(locale: :ja, page: 2)

    assert_select "main ul.job-posting-list li", count: 1
    assert_select "main a", text: @published.title
  end

  test "1 ページ目に前のページへの導線が出ない" do
    Pagination::DEFAULT_PER_PAGE.times { |index| create_job_posting(status: "published", title: "追加 #{index}") }

    get public_job_postings_path(locale: :ja)

    assert_select "nav.pagination a", text: I18n.t("shared.pagination.next"), count: 1
    assert_select "nav.pagination a", text: I18n.t("shared.pagination.previous"), count: 0
  end

  test "最後のページに次のページへの導線が出ない" do
    Pagination::DEFAULT_PER_PAGE.times { |index| create_job_posting(status: "published", title: "追加 #{index}") }

    get public_job_postings_path(locale: :ja, page: 2)

    assert_select "nav.pagination a", text: I18n.t("shared.pagination.previous"), count: 1
    assert_select "nav.pagination a", text: I18n.t("shared.pagination.next"), count: 0
  end

  test "範囲外のページ番号でも例外にならない" do
    [ 0, -1, 999, "abc" ].each do |page|
      get public_job_postings_path(locale: :ja, page: page)

      assert_response :success, "page=#{page} で失敗した"
    end
  end

  test "ページ送りで絞り込みの条件が保たれる" do
    # 条件に一致する求人が 1 ページを超えないと、ページ送りが出ない。
    (Pagination::DEFAULT_PER_PAGE + 1).times { |index| create_job_posting(status: "published", title: "追加 #{index}") }

    get public_job_postings_path(locale: :ja, keyword: "追加")

    href = css_select("nav.pagination a").first["href"]

    assert_includes CGI.unescape(href), "keyword=追加"
  end

  test "条件を持たない 2 ページ目の canonical がそのページ自身になる" do
    # 2 ページ目を 1 ページ目の複製として扱うと、そこにしかない求人が索引されない。
    Pagination::DEFAULT_PER_PAGE.times { |index| create_job_posting(status: "published", title: "追加 #{index}") }

    get public_job_postings_path(locale: :ja, page: 2)

    assert_select "head link[rel=?][href=?]", "canonical",
      public_job_postings_url(locale: :ja, page: 2), count: 1
  end

  test "条件を持つ一覧の canonical はページも条件も持たない" do
    get public_job_postings_path(locale: :ja, keyword: "採用", page: 2)

    assert_select "head link[rel=?][href=?]", "canonical", public_job_postings_url(locale: :ja), count: 1
  end

  test "詳細に構造化データが 1 つ出る" do
    get public_job_posting_path(locale: :ja, id: @published)

    scripts = css_select("script[type='application/ld+json']")

    assert_equal 1, scripts.size

    data = JSON.parse(scripts.first.text)

    assert_equal "JobPosting", data["@type"]
    assert_equal @published.title, data["title"]
    assert_equal @published.description, data["description"]
    assert_equal @organization.name, data.dig("hiringOrganization", "name")
    assert_equal @published.created_at.to_date.iso8601, data["datePosted"]
  end

  test "構造化データに入力した項目が入る" do
    @published.update!(
      location: "東京", employment_type: "full_time",
      salary_currency: "JPY", annual_salary_min: 5_000_000, requirements: "実務経験 3 年以上"
    )

    get public_job_posting_path(locale: :ja, id: @published)

    data = JSON.parse(css_select("script[type='application/ld+json']").first.text)

    assert_equal "東京", data.dig("jobLocation", "address", "addressLocality")
    assert_equal "FULL_TIME", data["employmentType"]
    assert_equal "JPY", data.dig("baseSalary", "currency")
    assert_equal 5_000_000, data.dig("baseSalary", "value", "minValue")
    assert_equal "実務経験 3 年以上", data["qualifications"]
  end

  test "未入力の項目が構造化データに現れない" do
    # 空で書くと、「値がない」ではなく「空という値がある」と解釈されうる。
    get public_job_posting_path(locale: :ja, id: @published)

    data = JSON.parse(css_select("script[type='application/ld+json']").first.text)

    %w[jobLocation employmentType baseSalary qualifications].each do |key|
      assert_not data.key?(key), "#{key} が現れている"
    end
  end

  test "一覧には構造化データを出さない" do
    get public_job_postings_path(locale: :ja)

    assert_select "script[type='application/ld+json']", count: 0
  end

  private
    def create_job_posting(status:, title:)
      @organization.job_postings.create!(status: status, title: title, description: "内容")
    end
end
