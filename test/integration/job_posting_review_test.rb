require "test_helper"

# 求人の公開申請と審査の契約を検証する。
#
# 検証対象は、誰がどの遷移を通せるかである。
class JobPostingReviewTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct horse battery".freeze

  setup do
    @owner = confirmed_user("owner@example.com")
    @organization = Organization.create_with_owner!(name: "Example Inc.", user: @owner)
    @member = confirmed_user("member@example.com")
    @organization.memberships.create!(user: @member, role: "member")

    @job_posting = @organization.job_postings.create!(
      status: "draft", title: "採用担当", description: "採用の実務を担当します。"
    )
  end

  test "所属者は下書きを申請できる" do
    # 申請は役割を問わない。日々の作業が管理者の手を経ずに進む。
    sign_in_as(@member)

    submit

    assert_equal "pending_review", @job_posting.reload.status
  end

  test "管理者は申請中の求人を承認できる" do
    @job_posting.update!(status: "pending_review")
    sign_in_as(@owner)

    approve

    assert_predicate @job_posting.reload, :published?
  end

  test "管理者は申請中の求人を差し戻せる" do
    @job_posting.update!(status: "pending_review")
    sign_in_as(@owner)

    reject

    assert_equal "rejected", @job_posting.reload.status
  end

  test "メンバーは承認できない" do
    @job_posting.update!(status: "pending_review")
    sign_in_as(@member)

    approve

    assert_response :not_found
    assert_equal "pending_review", @job_posting.reload.status
  end

  test "メンバーは差し戻せない" do
    @job_posting.update!(status: "pending_review")
    sign_in_as(@member)

    reject

    assert_response :not_found
    assert_equal "pending_review", @job_posting.reload.status
  end

  test "下書きを直接公開できない" do
    # 状態だけを増やして遷移を後回しにすると、想定しない組み合わせが生まれる。
    sign_in_as(@owner)

    approve

    assert_predicate @job_posting.reload, :draft?
  end

  test "公開中の求人をもう一度申請できない" do
    @job_posting.update!(status: "published")
    sign_in_as(@owner)

    submit

    assert_predicate @job_posting.reload, :published?
  end

  test "差し戻された求人を再申請できる" do
    @job_posting.update!(status: "rejected")
    sign_in_as(@member)

    submit

    assert_equal "pending_review", @job_posting.reload.status
  end

  test "許されていない遷移では理由を伝える" do
    sign_in_as(@owner)

    approve
    follow_redirect!

    assert_select "main .form-error", text: I18n.t("job_postings.review.rejected_transition")
  end

  test "申請中の求人を編集できない" do
    # 申請中と公開中の内容が、審査や公開の後で勝手に変わらないようにする。
    @job_posting.update!(status: "pending_review")
    sign_in_as(@owner)

    edit_title("書き換え")

    assert_response :not_found
    assert_equal "採用担当", @job_posting.reload.title
  end

  test "公開中の求人を編集できない" do
    @job_posting.update!(status: "published")
    sign_in_as(@owner)

    edit_title("書き換え")

    assert_response :not_found
    assert_equal "採用担当", @job_posting.reload.title
  end

  test "差し戻された求人は編集できる" do
    @job_posting.update!(status: "rejected")
    sign_in_as(@owner)

    edit_title("書き換え")

    assert_equal "書き換え", @job_posting.reload.title
  end

  test "状態をフォームから渡しても状態が変わらない" do
    # 編集の経路がそのまま公開の経路にならないようにする。
    sign_in_as(@owner)

    patch organization_job_posting_path(locale: :ja, organization_id: @organization, id: @job_posting),
          params: { job_posting: {
            title: @job_posting.title,
            description: @job_posting.description,
            status: "published"
          } }

    assert_predicate @job_posting.reload, :draft?
  end

  test "他組織の求人の状態を変えられない" do
    outsider = confirmed_user("outsider@example.com")
    other = Organization.create_with_owner!(name: "Another Inc.", user: outsider)
    sign_in_as(outsider)

    patch organization_job_posting_submit_path(
      locale: :ja, organization_id: other, job_posting_id: @job_posting
    )

    assert_response :not_found
    assert_predicate @job_posting.reload, :draft?
  end

  test "一覧に状態と行える操作だけが出る" do
    @job_posting.update!(status: "pending_review")
    sign_in_as(@owner)

    get organization_job_postings_path(locale: :ja, organization_id: @organization)

    assert_select "main li", text: /#{Regexp.escape(I18n.t("job_postings.statuses.pending_review"))}/
    assert_select "main a", text: I18n.t("job_postings.index.edit"), count: 0
    assert_select "main button", text: I18n.t("job_postings.index.approve"), count: 1
  end

  private
    def confirmed_user(email_address)
      User.create!(email_address: email_address, password: PASSWORD).tap(&:confirm)
    end

    def sign_in_as(user)
      post session_path(locale: :ja), params: { email_address: user.email_address, password: PASSWORD }
    end

    def submit
      patch organization_job_posting_submit_path(
        locale: :ja, organization_id: @organization, job_posting_id: @job_posting
      )
    end

    def approve
      patch organization_job_posting_approve_path(
        locale: :ja, organization_id: @organization, job_posting_id: @job_posting
      )
    end

    def reject
      patch organization_job_posting_reject_path(
        locale: :ja, organization_id: @organization, job_posting_id: @job_posting
      )
    end

    def edit_title(title)
      patch organization_job_posting_path(locale: :ja, organization_id: @organization, id: @job_posting),
            params: { job_posting: { title: title, description: @job_posting.description } }
    end
end
