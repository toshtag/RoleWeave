require "test_helper"

# 選考ステージの契約を検証する。
#
# 検証対象は、進める先の制限と、変更の記録である。
class SelectionStageTest < ActiveSupport::TestCase
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

  test "新しい応募は書類選考から始まる" do
    assert_equal "screening", @job_application.stage
  end

  test "定めた遷移だけができる" do
    assert @job_application.can_move_to?("interviewing")
    assert @job_application.can_move_to?("rejected")
    # 面接を飛ばして内定は出せない。
    assert_not @job_application.can_move_to?("offered")
    assert_not @job_application.can_move_to?("hired")
  end

  test "終わりのステージからは動かせない" do
    %w[hired rejected declined].each do |final_stage|
      @job_application.update_column(:stage, final_stage)

      JobApplication::STAGES.each do |stage|
        assert_not @job_application.can_move_to?(stage), "#{final_stage} から #{stage}"
      end
    end
  end

  test "取り消された応募のステージは動かせない" do
    # 応募者がもう選考を望んでいない。
    @job_application.withdraw

    assert_not @job_application.can_move_to?("interviewing")
    assert_not @job_application.move_to("interviewing", changed_by: @owner)
  end

  test "定めていないステージを保存できない" do
    @job_application.stage = "unknown"

    assert_not @job_application.valid?
  end

  test "確定のステージだけを管理者に限る" do
    assert JobApplication.owner_only_stage?("offered")
    assert JobApplication.owner_only_stage?("hired")
    assert JobApplication.owner_only_stage?("rejected")
    assert JobApplication.owner_only_stage?("declined")
    assert_not JobApplication.owner_only_stage?("interviewing")
  end

  test "ステージを進めると記録が残る" do
    assert_difference -> { JobApplicationEvent.count }, 1 do
      @job_application.move_to("interviewing", changed_by: @owner)
    end

    event = JobApplicationEvent.recent.first

    assert_equal "stage_changed", event.kind
    assert_equal "screening", event.from_stage
    assert_equal "interviewing", event.to_stage
    assert_equal @owner, event.changed_by
  end

  test "変更した利用者を削除しても記録は残る" do
    @job_application.move_to("interviewing", changed_by: @owner)

    another_owner = User.create!(email_address: "owner2@example.com", password: PASSWORD)
    @organization.memberships.create!(user: another_owner, role: "owner", changed_by: @owner)

    assert_no_difference -> { JobApplicationEvent.count } do
      AccountDeletion.new(@owner).delete!
    end

    event = JobApplicationEvent.recent.first

    assert_nil event.changed_by
    assert_equal "interviewing", event.to_stage
  end

  test "記録の内容を後から書き換えられない" do
    @job_application.move_to("interviewing", changed_by: @owner)

    assert_raises(ActiveRecord::ReadonlyAttributeError) do
      JobApplicationEvent.recent.first.update!(to_stage: "hired")
    end
  end

  test "ステージの変更の記録は変更前後を必ず持つ" do
    event = JobApplicationEvent.new(
      organization: @organization, kind: "stage_changed",
      job_posting_title: "サンプルの求人", candidate_display_name: "山田 太郎"
    )

    assert_not event.valid?
  end

  test "内定から採用と辞退の両方へ進める" do
    @job_application.update_column(:stage, "offered")

    assert @job_application.can_move_to?("hired")
    assert @job_application.can_move_to?("declined")
  end
end
