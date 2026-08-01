require "test_helper"

# 面接の予定と結論の期限の契約を検証する。
class InterviewScheduleTest < ActiveSupport::TestCase
  PASSWORD = "correct horse battery".freeze

  setup do
    candidate = User.create!(email_address: "candidate@example.com", password: PASSWORD).tap(&:confirm)
    @candidate_profile = candidate.create_candidate_profile!(display_name: "山田 太郎")

    @owner = User.create!(email_address: "owner@example.com", password: PASSWORD).tap(&:confirm)
    @organization = Organization.create_with_owner!(name: "サンプル株式会社", user: @owner)
    @job_posting = @organization.job_postings.create!(
      title: "サンプルの求人", description: "仕事の内容", status: "published"
    )
    @job_application = @candidate_profile.job_applications.create!(job_posting: @job_posting)
  end

  test "開始日時を持つ予定を作れる" do
    assert_predicate build, :valid?
  end

  test "開始日時のない予定を作れない" do
    assert_not build(starts_at: nil).valid?
  end

  test "過ぎた日時の予定を作れない" do
    # 過ぎた日時の予定は、予定ではない。
    assert_not build(starts_at: 1.hour.ago).valid?
  end

  test "所要時間は正の整数で、上限を超えない" do
    assert_not build(duration_minutes: 0).valid?
    assert_not build(duration_minutes: -30).valid?
    assert_predicate build(duration_minutes: InterviewSchedule::MAX_DURATION_MINUTES), :valid?
    assert_not build(duration_minutes: InterviewSchedule::MAX_DURATION_MINUTES + 1).valid?
  end

  test "1 つの応募に複数の予定を持てる" do
    build.save!
    build(starts_at: 3.days.from_now).save!

    assert_equal 2, @job_application.interview_schedules.count
  end

  test "予定を取り消せ、記録は残る" do
    schedule = build.tap(&:save!)

    assert_no_difference -> { InterviewSchedule.count } do
      assert schedule.cancel
    end

    assert_not_predicate schedule, :scheduled?
  end

  test "取り消した予定を再び取り消せない" do
    schedule = build.tap(&:save!)
    schedule.cancel

    assert_not schedule.cancel
  end

  test "予定の作成と取消が応募の記録へ残る" do
    schedule = nil

    assert_difference -> { JobApplicationEvent.where(kind: "interview_scheduled").count }, 1 do
      schedule = build.tap(&:save!)
    end

    assert_difference -> { JobApplicationEvent.where(kind: "interview_cancelled").count }, 1 do
      schedule.cancel
    end
  end

  test "作成した人を削除しても予定は残る" do
    another_owner = User.create!(email_address: "owner2@example.com", password: PASSWORD)
    @organization.memberships.create!(user: another_owner, role: "owner", changed_by: @owner)
    build.save!

    assert_no_difference -> { InterviewSchedule.count } do
      AccountDeletion.new(@owner).delete!
    end

    assert_nil InterviewSchedule.sole.created_by
  end

  test "応募を削除すると予定も消える" do
    build.save!

    assert_difference -> { InterviewSchedule.count }, -1 do
      @job_application.destroy
    end
  end

  test "結論の期限を設定でき、外せる" do
    assert @job_application.update(decide_by: Date.current + 7)
    assert @job_application.update(decide_by: nil)
  end

  test "過ぎた日付の期限を設定できない" do
    assert_not @job_application.update(decide_by: Date.current - 1)
  end

  test "本日の期限は設定できる" do
    assert @job_application.update(decide_by: Date.current)
  end

  test "期限を過ぎた応募が分かる" do
    @job_application.update!(decide_by: Date.current + 1)
    @job_application.update_column(:decide_by, Date.current - 1)

    assert_predicate @job_application.reload, :overdue?
    assert_includes JobApplication.overdue, @job_application
  end

  test "取り消された応募は期限切れとして数えない" do
    # 返事を待っているのは応募者であり、取り消した応募には相手がいない。
    @job_application.update!(decide_by: Date.current + 1)
    @job_application.update_column(:decide_by, Date.current - 1)
    @job_application.withdraw

    assert_not_predicate @job_application.reload, :overdue?
    assert_not_includes JobApplication.overdue, @job_application
  end

  private
    def build(overrides = {})
      @job_application.interview_schedules.build(
        { created_by: @owner, starts_at: 2.days.from_now, location: "本社 会議室" }.merge(overrides)
      )
    end
end
