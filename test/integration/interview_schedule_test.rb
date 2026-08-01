require "test_helper"

# 面接の予定と期限の経路の契約を検証する。
#
# 検証対象は、誰が扱えるかと、応募者側へ漏れないことである。
class InterviewScheduleRequestTest < ActionDispatch::IntegrationTest
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

  test "所属者が面接の予定を作れる" do
    sign_in_as(@member)

    assert_difference -> { InterviewSchedule.count }, 1 do
      post interviews_path, params: { interview_schedule: {
        starts_at: 2.days.from_now.change(sec: 0), location: "本社 会議室"
      } }
    end

    assert_equal @member, InterviewSchedule.sole.created_by
  end

  test "過ぎた日時の予定は保存されない" do
    sign_in_as(@member)

    assert_no_difference -> { InterviewSchedule.count } do
      post interviews_path, params: { interview_schedule: { starts_at: 1.day.ago } }
    end

    assert_equal I18n.t("organizations.interview_schedules.create.invalid"), flash[:alert]
  end

  test "未ログインでは予定を作れない" do
    post interviews_path, params: { interview_schedule: { starts_at: 2.days.from_now } }

    assert_redirected_to new_session_path(locale: :ja)
    assert_equal 0, InterviewSchedule.count
  end

  test "他組織の応募へ予定を作れない" do
    outsider = User.create!(email_address: "outsider@example.com", password: PASSWORD).tap(&:confirm)
    other_organization = Organization.create_with_owner!(name: "別の会社", user: outsider)
    sign_in_as(outsider)

    post organization_job_posting_application_interviews_path(
      locale: :ja, organization_id: other_organization,
      job_posting_id: @job_posting, application_id: @job_application
    ), params: { interview_schedule: { starts_at: 2.days.from_now } }

    assert_response :not_found
    assert_equal 0, InterviewSchedule.count
  end

  test "予定を取り消せる" do
    schedule = create_schedule
    sign_in_as(@member)

    delete organization_job_posting_application_interview_path(
      locale: :ja, organization_id: @organization,
      job_posting_id: @job_posting, application_id: @job_application, id: schedule
    )

    assert_not_predicate schedule.reload, :scheduled?
  end

  test "結論の期限を設定でき、外せる" do
    sign_in_as(@owner)

    patch deadline_path, params: { decide_by: (Date.current + 7).to_s }

    assert_equal Date.current + 7, @job_application.reload.decide_by

    patch deadline_path, params: { decide_by: "" }

    assert_nil @job_application.reload.decide_by
  end

  test "過ぎた日付の期限は保存されない" do
    sign_in_as(@owner)

    patch deadline_path, params: { decide_by: (Date.current - 1).to_s }

    assert_nil @job_application.reload.decide_by
    assert_equal I18n.t("organizations.job_application_deadlines.update.invalid"), flash[:alert]
  end

  test "期限を過ぎた応募が画面で分かる" do
    @job_application.update_column(:decide_by, Date.current - 1)
    sign_in_as(@owner)

    get application_path

    assert_select "main", text: /#{I18n.t("organizations.job_applications.show.overdue")}/
  end

  test "応募者側の画面に予定と期限が出ない" do
    # どちらも社内の情報である。
    create_schedule(location: "社内だけの会議室")
    @job_application.update!(decide_by: Date.current + 7)
    sign_in_as(@candidate)

    get profile_application_path(locale: :ja, id: @job_application)

    assert_response :success
    assert_no_match(/社内だけの会議室/, response.body)
    assert_no_match(/#{Date.current + 7}/, response.body)
  end

  test "エクスポートに予定と期限が出ない" do
    create_schedule(location: "社内だけの会議室")
    @job_application.update!(decide_by: Date.current + 7)
    sign_in_as(@candidate)

    get export_path(locale: :ja)

    assert_no_match(/社内だけの会議室/, response.body)
  end

  test "予定の画面を日本語と英語で表示する" do
    create_schedule
    sign_in_as(@owner)

    I18n.available_locales.each do |locale|
      get organization_job_posting_application_path(
        locale: locale, organization_id: @organization,
        job_posting_id: @job_posting, id: @job_application
      )

      assert_response :success
      assert_select "main h2",
                    text: I18n.t("organizations.job_applications.show.interviews", locale: locale)
    end
  end

  private
    def sign_in_as(user)
      post session_path(locale: :ja), params: { email_address: user.email_address, password: PASSWORD }
    end

    def create_schedule(location: "本社 会議室")
      @job_application.interview_schedules.create!(
        created_by: @owner, starts_at: 2.days.from_now, location: location
      )
    end

    def interviews_path
      organization_job_posting_application_interviews_path(
        locale: :ja, organization_id: @organization,
        job_posting_id: @job_posting, application_id: @job_application
      )
    end

    def deadline_path
      organization_job_posting_application_deadline_path(
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
