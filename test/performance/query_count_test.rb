require "test_helper"

# 一覧の画面が、件数に比例して問い合わせを増やさないことを検証する。
#
# N+1 は「動くが遅い」欠陥である。画面は正しく表示されるため、
# 通常のテストでは気付けない。
# 詳細は docs/decisions/0049-query-observability.md を参照する。
class QueryCountTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct horse battery".freeze

  setup do
    @candidate = User.create!(email_address: "candidate@example.com", password: PASSWORD).tap(&:confirm)
    @candidate_profile = @candidate.create_candidate_profile!(display_name: "山田 太郎")

    @owner = User.create!(email_address: "owner@example.com", password: PASSWORD).tap(&:confirm)
    @organization = Organization.create_with_owner!(name: "サンプル株式会社", user: @owner)
  end

  test "公開求人の一覧は件数に比例して問い合わせを増やさない" do
    3.times { |index| published_job_posting(title: "求人 #{index}") }
    baseline = count_queries { get public_job_postings_path(locale: :ja) }

    5.times { |index| published_job_posting(title: "追加の求人 #{index}") }
    after = count_queries { get public_job_postings_path(locale: :ja) }

    assert_equal baseline, after, "求人が増えると問い合わせも増えている（N+1）"
  end

  test "応募の一覧は件数に比例して問い合わせを増やさない" do
    job_posting = published_job_posting
    sign_in_as(@owner)
    2.times { |index| applicant(index).job_applications.create!(job_posting: job_posting) }
    baseline = count_queries { get applications_path(job_posting) }

    3.times { |index| applicant(index + 10).job_applications.create!(job_posting: job_posting) }
    after = count_queries { get applications_path(job_posting) }

    assert_equal baseline, after, "応募が増えると問い合わせも増えている（N+1）"
  end

  test "やり取りは件数に比例して問い合わせを増やさない" do
    job_posting = published_job_posting
    application = @candidate_profile.job_applications.create!(job_posting: job_posting)
    conversation = Conversation.create!(job_application: application)
    sign_in_as(@candidate)

    2.times { |index| conversation.messages.create!(sender: @owner, body: "#{index} 通目") }
    baseline = count_queries { get application_conversation_path(locale: :ja, application_id: application) }

    3.times { |index| conversation.messages.create!(sender: @owner, body: "追加 #{index}") }
    after = count_queries { get application_conversation_path(locale: :ja, application_id: application) }

    # 既読の記録は未読の数だけ増える。読み出しの問い合わせが増えないことを見る。
    assert_operator after, :<=, baseline + 3, "メッセージが増えると読み出しの問い合わせも増えている（N+1）"
  end

  test "通知の一覧は件数に比例して問い合わせを増やさない" do
    sign_in_as(@candidate)
    2.times { Notification.create!(user: @candidate, kind: "stage_changed") }
    baseline = count_queries { get notifications_path(locale: :ja) }

    3.times { Notification.create!(user: @candidate, kind: "stage_changed") }
    after = count_queries { get notifications_path(locale: :ja) }

    assert_equal baseline, after, "通知が増えると問い合わせも増えている（N+1）"
  end

  test "数える補助が実際に数えている" do
    # 補助そのものが 0 を返し続けると、どのテストも通ってしまう。
    assert_operator count_queries { User.count }, :>=, 1
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

    def applicant(index)
      user = User.create!(email_address: "applicant#{index}@example.com", password: PASSWORD).tap(&:confirm)

      user.create_candidate_profile!(display_name: "応募者 #{index}")
    end

    def applications_path(job_posting)
      organization_job_posting_applications_path(
        locale: :ja, organization_id: @organization, job_posting_id: job_posting
      )
    end
end
