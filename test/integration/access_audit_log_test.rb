require "test_helper"

# 個人情報を読んだ操作の記録の契約を検証する。
#
# 検証対象は、何が記録され、何が記録されないかである。
class AccessAuditLogTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct horse battery".freeze

  setup do
    @candidate = User.create!(email_address: "candidate@example.com", password: PASSWORD).tap(&:confirm)
    @candidate_profile = @candidate.create_candidate_profile!(display_name: "山田 太郎")

    @owner = User.create!(email_address: "owner@example.com", password: PASSWORD).tap(&:confirm)
    @organization = Organization.create_with_owner!(name: "サンプル株式会社", user: @owner)
    @job_posting = @organization.job_postings.create!(
      title: "サンプルの求人", description: "仕事の内容", status: "published"
    )
    @job_application = @candidate_profile.job_applications.create!(job_posting: @job_posting)

    @operator = User.create!(email_address: "operator@example.com", password: PASSWORD).tap(&:confirm)
    @operator.update!(operator: true)
  end

  test "企業側がプロフィールを開くと記録が残る" do
    @candidate_profile.update!(visibility: "all_organizations")
    sign_in_as(@owner)

    assert_difference -> { AccessEvent.count }, 1 do
      get organization_candidate_profile_path(
        locale: :ja, organization_id: @organization, id: @candidate_profile
      )
    end

    event = AccessEvent.recent.first

    assert_equal "candidate_profile_viewed", event.action
    assert_equal @owner, event.actor
    assert_equal @organization, event.organization
    assert_equal "山田 太郎", event.subject_label
    assert_not_nil event.ip_address
  end

  test "見えないプロフィールへの試みでは記録が残らない" do
    # 読めていない操作は「読んだ」ではない。
    sign_in_as(@owner)

    assert_no_difference -> { AccessEvent.count } do
      get organization_candidate_profile_path(
        locale: :ja, organization_id: @organization, id: @candidate_profile
      )

      assert_response :not_found
    end
  end

  test "企業側が応募の詳細を開くと記録が残る" do
    sign_in_as(@owner)

    assert_difference -> { AccessEvent.where(action: "job_application_viewed").count }, 1 do
      get organization_job_posting_application_path(
        locale: :ja, organization_id: @organization,
        job_posting_id: @job_posting, id: @job_application
      )
    end
  end

  test "企業側が添付を取得すると記録が残る" do
    @candidate_profile.resume.attach(
      io: File.open(Rails.root.join("test/fixtures/files/resume.pdf")),
      filename: "resume.pdf", content_type: "application/pdf"
    )
    @candidate_profile.update!(visibility: "all_organizations", documents_visible: true)
    sign_in_as(@owner)

    assert_difference -> { AccessEvent.where(action: "candidate_document_downloaded").count }, 1 do
      get organization_candidate_profile_document_path(
        locale: :ja, organization_id: @organization,
        candidate_profile_id: @candidate_profile, kind: "resume"
      )
    end

    assert_match(/resume/, AccessEvent.recent.first.subject_label)
  end

  test "本人がエクスポートすると記録が残る" do
    sign_in_as(@candidate)

    assert_difference -> { AccessEvent.where(action: "personal_data_exported").count }, 1 do
      get export_path(locale: :ja)
    end

    assert_nil AccessEvent.recent.first.organization
  end

  test "対象を削除しても記録は残る" do
    @candidate_profile.update!(visibility: "all_organizations")
    sign_in_as(@owner)
    get organization_candidate_profile_path(
      locale: :ja, organization_id: @organization, id: @candidate_profile
    )

    assert_no_difference -> { AccessEvent.count } do
      @candidate_profile.destroy
    end

    assert_equal "山田 太郎", AccessEvent.recent.first.subject_label
  end

  test "記録を後から変えられない" do
    event = AccessEvent.record(action: "personal_data_exported", subject: @candidate,
                               subject_label: @candidate.email_address, actor: @candidate)

    assert_raises(ActiveRecord::ReadonlyAttributeError) { event.update!(subject_label: "書き換え") }
  end

  test "運営者だけが一覧を見られる" do
    AccessEvent.record(action: "personal_data_exported", subject: @candidate,
                       subject_label: @candidate.email_address, actor: @candidate)
    sign_in_as(@operator)

    get operator_access_events_path(locale: :ja)

    assert_response :success
    assert_select "main", text: /candidate@example.com/
  end

  test "運営者でない利用者は一覧を見られない" do
    sign_in_as(@owner)

    get operator_access_events_path(locale: :ja)

    assert_response :not_found
  end

  test "保持期限の対象に入っている" do
    assert_includes DataRetention::POLICIES.keys, "access_events"
  end

  test "一覧を日本語と英語で表示する" do
    sign_in_as(@operator)

    I18n.available_locales.each do |locale|
      get operator_access_events_path(locale: locale)

      assert_response :success
      assert_select "main h1", text: I18n.t("operator.access_events.index.title", locale: locale)
    end
  end

  private
    def sign_in_as(user)
      post session_path(locale: :ja), params: { email_address: user.email_address, password: PASSWORD }
    end
end
