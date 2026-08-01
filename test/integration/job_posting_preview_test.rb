require "test_helper"

# 求人のプレビューの契約を検証する。
#
# 検証対象は、誰が見られるかと、公開時の見え方に何が出るかである。
class JobPostingPreviewTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct horse battery".freeze

  setup do
    @member = confirmed_user("member@example.com")
    @organization = Organization.create_with_owner!(name: "Example Inc.", user: @member)
    @job_posting = @organization.job_postings.create!(
      status: "draft",
      title: "採用担当",
      description: "採用の実務を担当します。",
      location: "東京",
      occupation: "人事",
      employment_type: "full_time",
      salary: "年収 500 万円",
      requirements: "実務経験 3 年以上"
    )
  end

  test "所属者はプレビューを見られる" do
    sign_in_as(@member)

    get preview_path

    assert_response :success
    assert_select "main h1", text: @job_posting.title
  end

  test "所属していないアカウントはプレビューを見られない" do
    sign_in_as(confirmed_user("outsider@example.com"))

    get preview_path

    assert_response :not_found
  end

  test "未ログインではプレビューを見られない" do
    get preview_path

    assert_redirected_to new_session_path(locale: :ja)
  end

  test "どの状態の求人でもプレビューできる" do
    sign_in_as(@member)

    JobPosting::STATUSES.each do |status|
      @job_posting.update_column(:status, status)

      get preview_path

      assert_response :success, "#{status} の求人をプレビューできない"
    end
  end

  test "入力した項目がすべて出る" do
    sign_in_as(@member)

    get preview_path

    assert_select "main", text: /#{Regexp.escape(@organization.name)}/
    [ @job_posting.location, @job_posting.occupation, @job_posting.salary ].each do |value|
      assert_select "main dd", text: value
    end
    assert_select "main dd", text: I18n.t("job_postings.employment_types.full_time")
    assert_select "main", text: /#{Regexp.escape(@job_posting.requirements)}/
  end

  test "未入力の項目は表示されない" do
    # 空欄を並べると、その項目が「無い」のか「書かれていない」のかが分からない。
    @job_posting.update!(location: nil, occupation: nil, employment_type: nil, salary: nil, requirements: nil)
    sign_in_as(@member)

    get preview_path

    assert_select "main dd", count: 0
    assert_select "main h2", text: JobPosting.human_attribute_name(:requirements), count: 0
  end

  test "プレビューであることが画面から分かる" do
    sign_in_as(@member)

    get preview_path

    assert_select "main .notice",
      text: I18n.t("job_postings.preview.notice", status: I18n.t("job_postings.statuses.draft"))
  end

  test "プレビューを検索結果へ載せない" do
    # 公開前の内容が検索から到達できると、公開の判断より先に外へ出る。
    sign_in_as(@member)

    get preview_path

    assert_select "head meta[name=?][content=?]", "robots", "noindex, nofollow", count: 1
  end

  test "他の画面は検索結果から外さない" do
    sign_in_as(@member)

    get organization_job_postings_path(locale: :ja, organization_id: @organization)

    assert_select "head meta[name=?]", "robots", count: 0
  end

  test "プレビューを日本語と英語で表示する" do
    sign_in_as(@member)

    I18n.available_locales.each do |locale|
      get preview_organization_job_posting_path(
        locale: locale, organization_id: @organization, id: @job_posting
      )

      assert_response :success
      assert_select "html[lang=?]", locale.to_s
    end
  end

  test "自組織の経路から他組織の求人をプレビューできない" do
    # 組織だけを自分のものにして、対象の求人を他組織のものにする。
    outsider = confirmed_user("outsider@example.com")
    other = Organization.create_with_owner!(name: "Another Inc.", user: outsider)
    other_posting = other.job_postings.create!(status: "draft", title: "他組織の求人", description: "内容")
    sign_in_as(@member)

    get preview_organization_job_posting_path(
      locale: :ja, organization_id: @organization, id: other_posting
    )

    assert_response :not_found
  end

  private
    def confirmed_user(email_address)
      User.create!(email_address: email_address, password: PASSWORD).tap(&:confirm)
    end

    def sign_in_as(user)
      post session_path(locale: :ja), params: { email_address: user.email_address, password: PASSWORD }
    end

    def preview_path
      preview_organization_job_posting_path(locale: :ja, organization_id: @organization, id: @job_posting)
    end
end
