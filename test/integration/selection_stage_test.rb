require "test_helper"

# 選考ステージを進める経路の契約を検証する。
#
# 検証対象は、誰がどの操作を行えるかである。
class SelectionStageRequestTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct horse battery".freeze

  setup do
    candidate = User.create!(email_address: "candidate@example.com", password: PASSWORD).tap(&:confirm)
    @candidate_profile = candidate.create_candidate_profile!(display_name: "山田 太郎")

    @owner = User.create!(email_address: "owner@example.com", password: PASSWORD).tap(&:confirm)
    @organization = Organization.create_with_owner!(name: "サンプル株式会社", user: @owner)
    @member = User.create!(email_address: "member@example.com", password: PASSWORD).tap(&:confirm)
    Membership.create!(organization: @organization, user: @member, role: "member")

    @job_posting = @organization.job_postings.create!(
      title: "サンプルの求人", description: "仕事の内容", status: "published"
    )
    @job_application = @candidate_profile.job_applications.create!(job_posting: @job_posting)
  end

  test "未ログインではステージを変えられない" do
    patch stage_path("interviewing")

    assert_redirected_to new_session_path(locale: :ja)
    assert_equal "screening", @job_application.reload.stage
  end

  test "一般の所属者が面接へ進められる" do
    sign_in_as(@member)

    patch stage_path("interviewing")

    assert_equal "interviewing", @job_application.reload.stage
  end

  test "一般の所属者は不採用を確定できない" do
    # 採否は、その後の関係を決める操作である。
    sign_in_as(@member)

    patch stage_path("rejected")

    assert_response :not_found
    assert_equal "screening", @job_application.reload.stage
  end

  test "一般の所属者は内定を出せない" do
    @job_application.update_column(:stage, "interviewing")
    sign_in_as(@member)

    patch stage_path("offered")

    assert_response :not_found
    assert_equal "interviewing", @job_application.reload.stage
  end

  test "管理者は確定を行える" do
    sign_in_as(@owner)

    patch stage_path("rejected")

    assert_equal "rejected", @job_application.reload.stage
  end

  test "定めていない遷移は拒否される" do
    sign_in_as(@owner)

    patch stage_path("hired")

    assert_equal "screening", @job_application.reload.stage
    assert_equal I18n.t("organizations.job_application_stages.update.invalid_transition"), flash[:alert]
  end

  test "定めていないステージ名は 404 になる" do
    # 受け取った文字列をそのまま渡すと、定めていない状態へ書き換えられる。
    sign_in_as(@owner)

    patch stage_path("unknown")

    assert_response :not_found
  end

  test "他組織の応募のステージを変えられない" do
    outsider = User.create!(email_address: "outsider@example.com", password: PASSWORD).tap(&:confirm)
    other_organization = Organization.create_with_owner!(name: "別の会社", user: outsider)
    sign_in_as(outsider)

    patch organization_job_posting_application_stage_path(
      locale: :ja, organization_id: other_organization,
      job_posting_id: @job_posting, application_id: @job_application, stage: "interviewing"
    )

    assert_response :not_found
    assert_equal "screening", @job_application.reload.stage
  end

  test "画面にいま行える操作だけが出る" do
    sign_in_as(@member)

    get application_path

    assert_select "main", text: /#{I18n.t("job_applications.stage_actions.interviewing")}/
    # 確定は管理者だけへ出す。
    assert_select "main", text: /#{I18n.t("job_applications.stage_actions.rejected")}/, count: 0
  end

  test "管理者には確定の操作も出る" do
    sign_in_as(@owner)

    get application_path

    assert_select "main", text: /#{I18n.t("job_applications.stage_actions.rejected")}/
  end

  test "変更が履歴に出る" do
    sign_in_as(@owner)
    patch stage_path("interviewing")

    get organization_job_posting_applications_path(
      locale: :ja, organization_id: @organization, job_posting_id: @job_posting
    )

    assert_select "main", text: /#{I18n.t("job_applications.stages.interviewing")}/
    assert_select "main", text: /owner@example.com/
  end

  test "選考の画面を日本語と英語で表示する" do
    sign_in_as(@owner)

    I18n.available_locales.each do |locale|
      get organization_job_posting_application_path(
        locale: locale, organization_id: @organization,
        job_posting_id: @job_posting, id: @job_application
      )

      assert_response :success
      assert_select "main", text: /#{I18n.t("job_applications.stages.screening", locale: locale)}/
    end
  end

  private
    def sign_in_as(user)
      post session_path(locale: :ja), params: { email_address: user.email_address, password: PASSWORD }
    end

    def stage_path(stage)
      organization_job_posting_application_stage_path(
        locale: :ja, organization_id: @organization,
        job_posting_id: @job_posting, application_id: @job_application, stage: stage
      )
    end

    def application_path
      organization_job_posting_application_path(
        locale: :ja, organization_id: @organization,
        job_posting_id: @job_posting, id: @job_application
      )
    end
end
