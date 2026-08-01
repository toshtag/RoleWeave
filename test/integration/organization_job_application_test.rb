require "test_helper"

# 企業側から見た応募の契約を検証する。
#
# 検証対象は、どの組織がどの応募を見られるかと、何を出すかである。
class OrganizationJobApplicationTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct horse battery".freeze

  setup do
    @candidate = User.create!(email_address: "candidate@example.com", password: PASSWORD).tap(&:confirm)
    @candidate_profile = @candidate.create_candidate_profile!(display_name: "山田 太郎")

    @recruiter = User.create!(email_address: "recruiter@example.com", password: PASSWORD).tap(&:confirm)
    @organization = Organization.create_with_owner!(name: "サンプル株式会社", user: @recruiter)
    @job_posting = published_job_posting
    @job_application = @candidate_profile.job_applications.create!(job_posting: @job_posting)
  end

  test "未ログインでは応募を見られない" do
    get applications_path

    assert_redirected_to new_session_path(locale: :ja)
  end

  test "メールアドレスが未確認では応募を見られない" do
    unconfirmed = User.create!(email_address: "unconfirmed@example.com", password: PASSWORD)
    Membership.create!(organization: @organization, user: unconfirmed, role: "member")
    sign_in_as(unconfirmed)

    get applications_path

    assert_response :forbidden
  end

  test "所属する組織の求人へ届いた応募の一覧を見られる" do
    sign_in_as(@recruiter)

    get applications_path

    assert_response :success
    assert_select "main", text: /山田 太郎/
  end

  test "一覧が新しい順に並ぶ" do
    later_candidate = User.create!(email_address: "later@example.com", password: PASSWORD).tap(&:confirm)
    later_profile = later_candidate.create_candidate_profile!(display_name: "後から応募した人")
    later_profile.job_applications.create!(job_posting: @job_posting)
    sign_in_as(@recruiter)

    get applications_path

    assert_operator response.body.index("後から応募した人"), :<, response.body.index("山田 太郎")
  end

  test "他組織の求人の応募は見られない" do
    outsider = User.create!(email_address: "outsider@example.com", password: PASSWORD).tap(&:confirm)
    other_organization = Organization.create_with_owner!(name: "別の会社", user: outsider)
    sign_in_as(outsider)

    get organization_job_posting_applications_path(
      locale: :ja, organization_id: other_organization, job_posting_id: @job_posting
    )

    assert_response :not_found
  end

  test "組織に所属しない利用者からは見られない" do
    sign_in_as(User.create!(email_address: "outsider@example.com", password: PASSWORD).tap(&:confirm))

    get applications_path

    assert_response :not_found
  end

  test "詳細が応募時点の写しを出す" do
    # 応募の後にプロフィールが変わっても、応募のときに渡された内容で判断する。
    @candidate_profile.update!(display_name: "書き換えた名前")
    sign_in_as(@recruiter)

    get application_path

    assert_response :success
    assert_select "main h1", text: "山田 太郎"
    assert_no_match(/書き換えた名前/, response.body)
  end

  test "取り消された応募も一覧と詳細に出る" do
    @job_application.withdraw
    sign_in_as(@recruiter)

    get applications_path

    assert_select "main", text: /#{I18n.t("candidate_job_applications.index.statuses.withdrawn")}/

    get application_path

    assert_select "main", text: /#{I18n.t("organizations.job_applications.show.withdrawn_notice")}/
  end

  test "応募先の組織から applied_organizations のプロフィールが見える" do
    @candidate_profile.update!(visibility: "applied_organizations")
    sign_in_as(@recruiter)

    get organization_candidate_profile_path(
      locale: :ja, organization_id: @organization, id: @candidate_profile
    )

    assert_response :success
  end

  test "応募していない組織からは applied_organizations のプロフィールが見えない" do
    @candidate_profile.update!(visibility: "applied_organizations")
    outsider = User.create!(email_address: "outsider@example.com", password: PASSWORD).tap(&:confirm)
    other_organization = Organization.create_with_owner!(name: "別の会社", user: outsider)
    sign_in_as(outsider)

    get organization_candidate_profile_path(
      locale: :ja, organization_id: other_organization, id: @candidate_profile
    )

    assert_response :not_found
  end

  test "応募を取り消すと applied_organizations のプロフィールは見えなくなる" do
    # 取り消した相手のプロフィールを見続けられるのは筋が通らない。
    @candidate_profile.update!(visibility: "applied_organizations")
    @job_application.withdraw
    sign_in_as(@recruiter)

    get organization_candidate_profile_path(
      locale: :ja, organization_id: @organization, id: @candidate_profile
    )

    assert_response :not_found
  end

  test "closed のプロフィールは、応募していても見えない" do
    sign_in_as(@recruiter)

    get organization_candidate_profile_path(
      locale: :ja, organization_id: @organization, id: @candidate_profile
    )

    assert_response :not_found
  end

  test "現在のプロフィールへの導線は、見られるときだけ出る" do
    sign_in_as(@recruiter)

    get application_path

    assert_select "main a", text: I18n.t("organizations.job_applications.show.current_profile"), count: 0

    @candidate_profile.update!(visibility: "applied_organizations")

    get application_path

    assert_select "main a", text: I18n.t("organizations.job_applications.show.current_profile")
  end

  test "添付の可否も同じ判定に従う" do
    @candidate_profile.resume.attach(
      io: File.open(Rails.root.join("test/fixtures/files/resume.pdf")),
      filename: "resume.pdf", content_type: "application/pdf"
    )
    @candidate_profile.update!(visibility: "applied_organizations", documents_visible: true)
    sign_in_as(@recruiter)

    get organization_candidate_profile_document_path(
      locale: :ja, organization_id: @organization,
      candidate_profile_id: @candidate_profile, kind: "resume"
    )

    assert_response :success

    @job_application.withdraw

    get organization_candidate_profile_document_path(
      locale: :ja, organization_id: @organization,
      candidate_profile_id: @candidate_profile, kind: "resume"
    )

    assert_response :not_found
  end

  test "応募の画面を日本語と英語で表示する" do
    sign_in_as(@recruiter)

    I18n.available_locales.each do |locale|
      get organization_job_posting_applications_path(
        locale: locale, organization_id: @organization, job_posting_id: @job_posting
      )

      assert_response :success
      assert_select "main h1",
                    text: I18n.t("organizations.job_applications.index.title",
                                 title: @job_posting.title, locale: locale)
    end
  end

  private
    def sign_in_as(user)
      post session_path(locale: :ja), params: { email_address: user.email_address, password: PASSWORD }
    end

    def published_job_posting(title: "サンプルの求人")
      @organization.job_postings.create!(
        title: title, description: "仕事の内容", status: "published"
      )
    end

    def applications_path
      organization_job_posting_applications_path(
        locale: :ja, organization_id: @organization, job_posting_id: @job_posting
      )
    end

    def application_path
      organization_job_posting_application_path(
        locale: :ja, organization_id: @organization,
        job_posting_id: @job_posting, id: @job_application
      )
    end
end
