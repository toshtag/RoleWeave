require "test_helper"

# 求人の公開状態の記録の契約を検証する。
#
# 検証対象は、記録できる値と削除したときの扱いである。
# どの操作でどの記録が残るかは integration のテストが持つ。
class JobPostingEventTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(name: "Example Inc.")
  end

  test "求人を作ると作成が記録される" do
    assert_difference -> { JobPostingEvent.count }, 1 do
      create_job_posting
    end

    event = JobPostingEvent.last

    assert_predicate event, :created?
    assert_equal "draft", event.to_status
    assert_equal "採用担当", event.job_posting_title
  end

  test "状態を変えると変更前と変更後が残る" do
    job_posting = create_job_posting

    assert_difference -> { JobPostingEvent.count }, 1 do
      job_posting.transition_to("pending_review")
    end

    event = JobPostingEvent.last

    assert_equal "draft", event.from_status
    assert_equal "pending_review", event.to_status
  end

  test "状態以外の変更では記録が増えない" do
    job_posting = create_job_posting

    assert_no_difference -> { JobPostingEvent.count } do
      job_posting.update!(title: "編集後")
    end
  end

  test "変更した主体を記録する" do
    user = User.create!(email_address: "member@example.com", password: "correct horse battery")
    job_posting = create_job_posting
    job_posting.changed_by = user

    job_posting.transition_to("pending_review")

    assert_equal user, JobPostingEvent.last.changed_by
  end

  test "求人を削除しても記録は残る" do
    job_posting = create_job_posting

    assert_no_difference -> { JobPostingEvent.count } do
      job_posting.destroy
    end

    assert_nil JobPostingEvent.last.job_posting_id
    assert_equal "採用担当", JobPostingEvent.last.job_posting_title
  end

  test "組織を削除しても記録は残る" do
    create_job_posting

    assert_no_difference -> { JobPostingEvent.count } do
      @organization.destroy
    end

    assert_nil JobPostingEvent.last.organization_id
  end

  test "記録した内容を後から変えられない" do
    create_job_posting

    assert_raises(ActiveRecord::ReadonlyAttributeError) do
      JobPostingEvent.last.update!(to_status: "published")
    end
  end

  test "決められた状態だけを受け付ける" do
    assert_not JobPostingEvent.new(to_status: "unknown", job_posting_title: "採用担当").valid?
    assert_not JobPostingEvent.new(to_status: "draft", from_status: "unknown", job_posting_title: "採用担当").valid?
  end

  private
    def create_job_posting
      @organization.job_postings.create!(
        status: "draft", title: "採用担当", description: "採用の実務を担当します。"
      )
    end
end
