require "test_helper"

# 求人の下書きの作成と編集の契約を検証する。
#
# 検証対象は、誰がどの組織の求人を扱えるかである。
class JobPostingManagementTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct horse battery".freeze

  setup do
    @member = confirmed_user("member@example.com")
    @organization = Organization.create_with_owner!(name: "Example Inc.", user: @member)

    @outsider = confirmed_user("outsider@example.com")
    @other_organization = Organization.create_with_owner!(name: "Another Inc.", user: @outsider)
  end

  test "所属するアカウントは求人の下書きを作成できる" do
    sign_in_as(@member)

    assert_difference -> { JobPosting.count }, 1 do
      create_job_posting
    end

    assert_redirected_to organization_job_postings_path(locale: :ja, organization_id: @organization)
    assert_predicate JobPosting.last, :draft?
  end

  test "題名が空だと作成できない" do
    sign_in_as(@member)

    assert_no_difference -> { JobPosting.count } do
      create_job_posting(title: "  ")
    end

    assert_response :unprocessable_content
  end

  test "作成した求人を編集できる" do
    sign_in_as(@member)
    create_job_posting
    job_posting = JobPosting.last

    patch organization_job_posting_path(locale: :ja, organization_id: @organization, id: job_posting),
          params: { job_posting: { title: "編集後の題名", description: job_posting.description } }

    assert_equal "編集後の題名", job_posting.reload.title
  end

  test "画面から公開状態を変えられない" do
    # 公開状態を変える経路は別に用意する。
    sign_in_as(@member)
    create_job_posting
    job_posting = JobPosting.last

    patch organization_job_posting_path(locale: :ja, organization_id: @organization, id: job_posting),
          params: { job_posting: { title: job_posting.title, description: job_posting.description, status: "published" } }

    assert_predicate job_posting.reload, :draft?
  end

  test "所属していない組織の求人を一覧できない" do
    sign_in_as(@member)

    get organization_job_postings_path(locale: :ja, organization_id: @other_organization)

    assert_response :not_found
  end

  test "所属していない組織へ求人を作成できない" do
    sign_in_as(@member)

    assert_no_difference -> { JobPosting.count } do
      post organization_job_postings_path(locale: :ja, organization_id: @other_organization),
           params: { job_posting: { title: "採用担当", description: "内容" } }
    end

    assert_response :not_found
  end

  test "他組織の求人を自組織の経路から編集できない" do
    other_posting = @other_organization.job_postings.create!(
      status: "draft", title: "他組織の求人", description: "内容"
    )
    sign_in_as(@member)

    patch organization_job_posting_path(locale: :ja, organization_id: @organization, id: other_posting),
          params: { job_posting: { title: "書き換え", description: "内容" } }

    assert_response :not_found
    assert_equal "他組織の求人", other_posting.reload.title
  end

  test "未ログインでは求人を扱えない" do
    get organization_job_postings_path(locale: :ja, organization_id: @organization)

    assert_redirected_to new_session_path(locale: :ja)
  end

  test "メールアドレスが未確認では求人を扱えない" do
    unconfirmed = User.create!(email_address: "unconfirmed@example.com", password: PASSWORD)
    @organization.memberships.create!(user: unconfirmed, role: "member")
    sign_in_as(unconfirmed)

    get organization_job_postings_path(locale: :ja, organization_id: @organization)

    assert_response :forbidden
  end

  test "自組織の求人だけが一覧に出る" do
    @organization.job_postings.create!(status: "draft", title: "自組織の求人", description: "内容")
    @other_organization.job_postings.create!(status: "draft", title: "他組織の求人", description: "内容")
    sign_in_as(@member)

    get organization_job_postings_path(locale: :ja, organization_id: @organization)

    # 履歴の一覧にも題名が現れるため、求人の一覧の項目だけを見る。
    assert_select "main ul:first-of-type li", text: /自組織の求人/, count: 1
    assert_select "main li", text: /他組織の求人/, count: 0
  end

  test "一覧と作成の画面を日本語と英語で表示する" do
    sign_in_as(@member)

    I18n.available_locales.each do |locale|
      get organization_job_postings_path(locale: locale, organization_id: @organization)

      assert_response :success
      assert_select "main h1",
        text: I18n.t("job_postings.index.title", organization: @organization.name, locale: locale)

      get new_organization_job_posting_path(locale: locale, organization_id: @organization)

      assert_response :success
    end
  end

  private
    def confirmed_user(email_address)
      User.create!(email_address: email_address, password: PASSWORD).tap(&:confirm)
    end

    def sign_in_as(user)
      post session_path(locale: :ja), params: { email_address: user.email_address, password: PASSWORD }
    end

    def create_job_posting(title: "採用担当", description: "採用の実務を担当します。")
      post organization_job_postings_path(locale: :ja, organization_id: @organization),
           params: { job_posting: { title: title, description: description } }
    end
end
