require "test_helper"

# 求人の公開状態の履歴が、経路を問わず残ることを検証する。
#
# 記録は後から足せない。過去の出来事は復元できないため、
# 状態を変える経路ごとに残ることをここで固定する。
class JobPostingHistoryTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct horse battery".freeze

  setup do
    @owner = confirmed_user("owner@example.com")
    @organization = Organization.create_with_owner!(name: "Example Inc.", user: @owner)
    @member = confirmed_user("member@example.com")
    @organization.memberships.create!(user: @member, role: "member")
  end

  test "求人の作成が記録され主体が残る" do
    sign_in_as(@member)

    assert_difference -> { JobPostingEvent.count }, 1 do
      post organization_job_postings_path(locale: :ja, organization_id: @organization),
           params: { job_posting: { title: "採用担当", description: "内容" } }
    end

    event = JobPostingEvent.last

    assert_predicate event, :created?
    assert_equal @member, event.changed_by
  end

  test "申請・承認・停止のそれぞれが記録される" do
    job_posting = create_job_posting
    sign_in_as(@member)

    assert_difference -> { JobPostingEvent.count }, 1 do
      patch organization_job_posting_submit_path(locale: :ja, organization_id: @organization, job_posting_id: job_posting)
    end

    sign_in_as(@owner)

    assert_difference -> { JobPostingEvent.count }, 1 do
      patch organization_job_posting_approve_path(locale: :ja, organization_id: @organization, job_posting_id: job_posting)
    end

    assert_difference -> { JobPostingEvent.count }, 1 do
      patch organization_job_posting_suspend_path(locale: :ja, organization_id: @organization, job_posting_id: job_posting)
    end

    assert_equal %w[draft pending_review published suspended],
                 JobPostingEvent.order(:id).pluck(:to_status)
  end

  test "差し戻しの主体が記録される" do
    # 差し戻しの理由は記録していない。少なくとも誰がいつ差し戻したかは残す。
    job_posting = create_job_posting(status: "pending_review")
    sign_in_as(@owner)

    patch organization_job_posting_reject_path(locale: :ja, organization_id: @organization, job_posting_id: job_posting)

    event = JobPostingEvent.last

    assert_equal "rejected", event.to_status
    assert_equal @owner, event.changed_by
  end

  test "許されていない遷移では記録が増えない" do
    job_posting = create_job_posting
    sign_in_as(@owner)

    assert_no_difference -> { JobPostingEvent.count } do
      patch organization_job_posting_approve_path(locale: :ja, organization_id: @organization, job_posting_id: job_posting)
    end
  end

  test "所属者は履歴を見られる" do
    create_job_posting
    sign_in_as(@member)

    get organization_job_postings_path(locale: :ja, organization_id: @organization)

    assert_response :success
    assert_select "main h2", text: I18n.t("job_postings.index.history")
  end

  test "所属していないアカウントは履歴を見られない" do
    outsider = confirmed_user("outsider@example.com")
    create_job_posting
    sign_in_as(outsider)

    get organization_job_postings_path(locale: :ja, organization_id: @organization)

    assert_response :not_found
  end

  test "履歴を日本語と英語で表示する" do
    create_job_posting
    sign_in_as(@owner)

    I18n.available_locales.each do |locale|
      get organization_job_postings_path(locale: locale, organization_id: @organization)

      assert_response :success
      assert_select "main h2", text: I18n.t("job_postings.index.history", locale: locale)
    end
  end

  private
    def confirmed_user(email_address)
      User.create!(email_address: email_address, password: PASSWORD).tap(&:confirm)
    end

    def sign_in_as(user)
      post session_path(locale: :ja), params: { email_address: user.email_address, password: PASSWORD }
    end

    def create_job_posting(status: "draft")
      @organization.job_postings.create!(status: status, title: "採用担当", description: "内容")
    end
end
