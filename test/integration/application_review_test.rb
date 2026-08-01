require "test_helper"

# 評価と担当者の経路の契約を検証する。
#
# 検証対象は、誰が読み書きできるかと、応募者側へ漏れないことである。
class ApplicationReviewRequestTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct horse battery".freeze

  setup do
    @candidate = User.create!(email_address: "candidate@example.com", password: PASSWORD).tap(&:confirm)
    @candidate_profile = @candidate.create_candidate_profile!(display_name: "山田 太郎")

    @owner = User.create!(email_address: "owner@example.com", password: PASSWORD).tap(&:confirm)
    @organization = Organization.create_with_owner!(name: "サンプル株式会社", user: @owner)
    @member = User.create!(email_address: "member@example.com", password: PASSWORD).tap(&:confirm)
    Membership.create!(organization: @organization, user: @member, role: "member")

    @job_posting = @organization.job_postings.create!(
      title: "サンプルの求人", description: "仕事の内容", status: "published"
    )
    @job_application = @candidate_profile.job_applications.create!(job_posting: @job_posting)
  end

  test "所属者が評価を記録できる" do
    sign_in_as(@member)

    assert_difference -> { ApplicationReview.count }, 1 do
      post reviews_path, params: { application_review: { rating: 4, comment: "良い経歴だった" } }
    end

    assert_equal @member, ApplicationReview.sole.reviewer
  end

  test "評価もコメントもない記録は保存されない" do
    sign_in_as(@member)

    assert_no_difference -> { ApplicationReview.count } do
      post reviews_path, params: { application_review: { rating: "", comment: "" } }
    end

    assert_equal I18n.t("organizations.application_reviews.create.invalid"), flash[:alert]
  end

  test "未ログインでは評価を記録できない" do
    post reviews_path, params: { application_review: { rating: 4 } }

    assert_redirected_to new_session_path(locale: :ja)
    assert_equal 0, ApplicationReview.count
  end

  test "組織に所属しない利用者は評価を記録できない" do
    sign_in_as(User.create!(email_address: "outsider@example.com", password: PASSWORD).tap(&:confirm))

    post reviews_path, params: { application_review: { rating: 4 } }

    assert_response :not_found
    assert_equal 0, ApplicationReview.count
  end

  test "他組織の応募へ評価を記録できない" do
    outsider = User.create!(email_address: "outsider@example.com", password: PASSWORD).tap(&:confirm)
    other_organization = Organization.create_with_owner!(name: "別の会社", user: outsider)
    sign_in_as(outsider)

    post organization_job_posting_application_reviews_path(
      locale: :ja, organization_id: other_organization,
      job_posting_id: @job_posting, application_id: @job_application
    ), params: { application_review: { rating: 4 } }

    assert_response :not_found
    assert_equal 0, ApplicationReview.count
  end

  test "所属者は評価の一覧を読める" do
    @job_application.application_reviews.create!(reviewer: @owner, rating: 2, comment: "内部の評価")
    sign_in_as(@member)

    get application_path

    assert_response :success
    assert_select "main", text: /内部の評価/
  end

  test "求職者側の応募の画面に評価が出ない" do
    # 社内の判断の材料であり、応募者には見せない。
    @job_application.application_reviews.create!(reviewer: @owner, rating: 2, comment: "内部の評価")
    sign_in_as(@candidate)

    get profile_application_path(locale: :ja, id: @job_application)

    assert_response :success
    assert_no_match(/内部の評価/, response.body)
  end

  test "エクスポートに評価が出ない" do
    @job_application.application_reviews.create!(reviewer: @owner, rating: 2, comment: "内部の評価")
    sign_in_as(@candidate)

    get export_path(locale: :ja)

    assert_no_match(/内部の評価/, response.body)
  end

  test "担当者を所属者から選べる" do
    sign_in_as(@owner)

    patch assignment_path, params: { assignee_id: @member.id }

    assert_equal @member, @job_application.reload.assignee
  end

  test "所属していない利用者を担当者にできない" do
    outsider = User.create!(email_address: "outsider@example.com", password: PASSWORD).tap(&:confirm)
    sign_in_as(@owner)

    patch assignment_path, params: { assignee_id: outsider.id }

    assert_nil @job_application.reload.assignee
    assert_equal I18n.t("organizations.job_application_assignments.update.invalid"), flash[:alert]
  end

  test "担当者を外せる" do
    @job_application.update!(assignee: @member)
    sign_in_as(@owner)

    patch assignment_path, params: { assignee_id: "" }

    assert_nil @job_application.reload.assignee
  end

  test "評価の画面を日本語と英語で表示する" do
    sign_in_as(@owner)

    I18n.available_locales.each do |locale|
      get organization_job_posting_application_path(
        locale: locale, organization_id: @organization,
        job_posting_id: @job_posting, id: @job_application
      )

      assert_response :success
      assert_select "main h2",
                    text: I18n.t("organizations.job_applications.show.reviews", locale: locale)
    end
  end

  private
    def sign_in_as(user)
      post session_path(locale: :ja), params: { email_address: user.email_address, password: PASSWORD }
    end

    def reviews_path
      organization_job_posting_application_reviews_path(
        locale: :ja, organization_id: @organization,
        job_posting_id: @job_posting, application_id: @job_application
      )
    end

    def assignment_path
      organization_job_posting_application_assignment_path(
        locale: :ja, organization_id: @organization,
        job_posting_id: @job_posting, application_id: @job_application
      )
    end

    def application_path
      organization_job_posting_application_path(
        locale: :ja, organization_id: @organization,
        job_posting_id: @job_posting, id: @job_application
      )
    end
end
