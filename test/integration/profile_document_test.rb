require "test_helper"

# 履歴書・職務経歴書の添付の契約を検証する。
#
# 検証対象は、何を受け付けるか、誰が取れるか、どう返すかである。
class ProfileDocumentTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct horse battery".freeze

  setup do
    @candidate = confirmed_user("candidate@example.com")
    @candidate_profile = @candidate.create_candidate_profile!(display_name: "山田 太郎")

    @recruiter = confirmed_user("recruiter@example.com")
    @organization = Organization.create_with_owner!(name: "サンプル株式会社", user: @recruiter)
  end

  test "未ログインでは添付を扱えない" do
    get edit_profile_documents_path(locale: :ja)

    assert_redirected_to new_session_path(locale: :ja)
  end

  test "メールアドレスが未確認では添付を扱えない" do
    unconfirmed = User.create!(email_address: "unconfirmed@example.com", password: PASSWORD)
    sign_in_as(unconfirmed)

    get edit_profile_documents_path(locale: :ja)

    assert_response :forbidden
  end

  test "履歴書と職務経歴書を添付できる" do
    sign_in_as(@candidate)

    patch profile_documents_path(locale: :ja), params: { candidate_profile: {
      resume: upload("resume.pdf"),
      curriculum_vitae: upload("curriculum_vitae.pdf")
    } }

    assert_redirected_to edit_profile_documents_path(locale: :ja)
    assert_predicate @candidate_profile.reload.resume, :attached?
    assert_predicate @candidate_profile.curriculum_vitae, :attached?
  end

  test "PDF 以外の形式を拒否する" do
    # Office 文書はマクロを持てるため、開く側の危険が増す。
    sign_in_as(@candidate)

    patch profile_documents_path(locale: :ja),
          params: { candidate_profile: { resume: upload("not_a_pdf.txt", "text/plain") } }

    assert_response :unprocessable_content
    assert_not_predicate @candidate_profile.reload.resume, :attached?
  end

  test "上限を超える大きさのファイルを拒否する" do
    sign_in_as(@candidate)
    oversized = Rack::Test::UploadedFile.new(
      StringIO.new("a" * (CandidateProfile::DOCUMENT_MAX_BYTE_SIZE + 1)),
      "application/pdf",
      original_filename: "resume.pdf"
    )

    patch profile_documents_path(locale: :ja), params: { candidate_profile: { resume: oversized } }

    assert_response :unprocessable_content
    assert_not_predicate @candidate_profile.reload.resume, :attached?
  end

  test "添付を差し替えると古いファイルが残らない" do
    sign_in_as(@candidate)
    attach_resume
    old_blob_id = @candidate_profile.reload.resume.blob.id

    patch profile_documents_path(locale: :ja),
          params: { candidate_profile: { resume: upload("curriculum_vitae.pdf") } }

    assert_not_equal old_blob_id, @candidate_profile.reload.resume.blob.id
    assert_equal 1, @candidate_profile.reload.resume.attachment ? 1 : 0
    assert_not ActiveStorage::Attachment.exists?(blob_id: old_blob_id)
  end

  test "添付を削除できる" do
    sign_in_as(@candidate)
    attach_resume

    delete profile_document_path(locale: :ja, kind: "resume")

    assert_redirected_to edit_profile_documents_path(locale: :ja)
    assert_not_predicate @candidate_profile.reload.resume, :attached?
  end

  test "本人が自分の添付をダウンロードできる" do
    sign_in_as(@candidate)
    attach_resume

    get profile_document_path(locale: :ja, kind: "resume")

    assert_response :success
    assert_equal "application/pdf", response.media_type
  end

  test "ダウンロードは添付として返る" do
    # ブラウザーの中で開かせない。
    sign_in_as(@candidate)
    attach_resume

    get profile_document_path(locale: :ja, kind: "resume")

    assert_match(/\Aattachment;/, response.headers["Content-Disposition"])
  end

  test "決まった種類以外を受け取らない" do
    # 受け取った文字列をそのまま呼び出すと、ほかのメソッドを呼べてしまう。
    sign_in_as(@candidate)

    get profile_document_path(locale: :ja, kind: "user")

    assert_response :not_found
  end

  test "添付がない種類は 404 になる" do
    sign_in_as(@candidate)

    get profile_document_path(locale: :ja, kind: "resume")

    assert_response :not_found
  end

  test "公開範囲が閉じていれば、見せる設定でも企業から取れない" do
    attach_resume
    @candidate_profile.update!(visibility: "closed", documents_visible: true)
    sign_in_as(@recruiter)

    get organization_candidate_profile_document_path(
      locale: :ja, organization_id: @organization,
      candidate_profile_id: @candidate_profile, kind: "resume"
    )

    assert_response :not_found
  end

  test "見せない設定であれば、公開範囲が開いていても企業から取れない" do
    attach_resume
    @candidate_profile.update!(visibility: "all_organizations", documents_visible: false)
    sign_in_as(@recruiter)

    get organization_candidate_profile_document_path(
      locale: :ja, organization_id: @organization,
      candidate_profile_id: @candidate_profile, kind: "resume"
    )

    assert_response :not_found
  end

  test "両方が開いているときだけ企業がダウンロードできる" do
    attach_resume
    @candidate_profile.update!(visibility: "all_organizations", documents_visible: true)
    sign_in_as(@recruiter)

    get organization_candidate_profile_document_path(
      locale: :ja, organization_id: @organization,
      candidate_profile_id: @candidate_profile, kind: "resume"
    )

    assert_response :success
    assert_match(/\Aattachment;/, response.headers["Content-Disposition"])
  end

  test "組織に所属しない利用者は企業側の経路を使えない" do
    attach_resume
    @candidate_profile.update!(visibility: "all_organizations", documents_visible: true)
    sign_in_as(confirmed_user("outsider@example.com"))

    get organization_candidate_profile_document_path(
      locale: :ja, organization_id: @organization,
      candidate_profile_id: @candidate_profile, kind: "resume"
    )

    assert_response :not_found
  end

  test "他人の添付を本人用の経路から取れない" do
    # 経路が ID を受け取らないため、対象は常に自分のプロフィールになる。
    other = confirmed_user("other@example.com")
    other_profile = other.create_candidate_profile!(display_name: "他人の名前")
    other_profile.resume.attach(io: file_io("resume.pdf"), filename: "resume.pdf",
                                content_type: "application/pdf")
    sign_in_as(@candidate)

    get profile_document_path(locale: :ja, kind: "resume")

    assert_response :not_found
  end

  test "プロフィールを削除すると添付も消える" do
    attach_resume

    assert_difference -> { ActiveStorage::Attachment.count }, -1 do
      @candidate_profile.destroy
    end
  end

  test "企業側の詳細に添付の導線が出るのは、見せる設定のときだけ" do
    attach_resume
    @candidate_profile.update!(visibility: "all_organizations")
    sign_in_as(@recruiter)

    get organization_candidate_profile_path(locale: :ja, organization_id: @organization, id: @candidate_profile)

    assert_select "main a", text: CandidateProfile.human_attribute_name(:resume), count: 0

    @candidate_profile.update!(documents_visible: true)

    get organization_candidate_profile_path(locale: :ja, organization_id: @organization, id: @candidate_profile)

    assert_select "main a", text: CandidateProfile.human_attribute_name(:resume)
  end

  test "添付の画面を日本語と英語で表示する" do
    sign_in_as(@candidate)

    I18n.available_locales.each do |locale|
      get edit_profile_documents_path(locale: locale)

      assert_response :success
      assert_select "main h1", text: I18n.t("profile_documents.edit.title", locale: locale)
    end
  end

  private
    def confirmed_user(email_address)
      User.create!(email_address: email_address, password: PASSWORD).tap(&:confirm)
    end

    def sign_in_as(user)
      post session_path(locale: :ja), params: { email_address: user.email_address, password: PASSWORD }
    end

    def file_io(name)
      File.open(Rails.root.join("test/fixtures/files", name))
    end

    def upload(name, content_type = "application/pdf")
      Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files", name), content_type)
    end

    def attach_resume
      @candidate_profile.resume.attach(io: file_io("resume.pdf"), filename: "resume.pdf",
                                       content_type: "application/pdf")
    end
end
