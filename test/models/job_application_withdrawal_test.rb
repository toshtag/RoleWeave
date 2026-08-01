require "test_helper"

# 応募の取消の契約を検証する。
#
# 検証対象は、何度も取り消せないことと、記録が残ることである。
class JobApplicationWithdrawalTest < ActiveSupport::TestCase
  PASSWORD = "correct horse battery".freeze

  setup do
    candidate = User.create!(email_address: "candidate@example.com", password: PASSWORD).tap(&:confirm)
    @candidate_profile = candidate.create_candidate_profile!(display_name: "山田 太郎")

    recruiter = User.create!(email_address: "recruiter@example.com", password: PASSWORD).tap(&:confirm)
    organization = Organization.create_with_owner!(name: "サンプル株式会社", user: recruiter)
    @job_posting = organization.job_postings.create!(
      title: "サンプルの求人", description: "仕事の内容", status: "published"
    )
    @job_application = @candidate_profile.job_applications.create!(job_posting: @job_posting)
  end

  test "応募を取り消せる" do
    assert @job_application.withdraw
    assert_predicate @job_application, :withdrawn?
  end

  test "取り消しても記録は残る" do
    # 消すと、企業側から見て「応募がなかったこと」になる。
    assert_no_difference -> { JobApplication.count } do
      @job_application.withdraw
    end
  end

  test "取り消した応募を再び取り消せない" do
    @job_application.withdraw

    assert_not @job_application.withdraw
  end

  test "取り消しても応募時点の写しは変わらない" do
    snapshot = @job_application.job_posting_snapshot

    @job_application.withdraw

    assert_equal snapshot, @job_application.reload.job_posting_snapshot
  end

  test "取り消した後も同じ求人へ応募し直せない" do
    # 同じ求人に同じ人の応募が複数並ぶと、企業側がどれを見ればよいか判断できない。
    @job_application.withdraw

    assert_not @candidate_profile.job_applications.build(job_posting: @job_posting).valid?
  end
end
