require "test_helper"

# 求職者から見た応募の一覧・詳細・取消の契約を検証する。
#
# 検証対象は、誰の応募が見えるかと、何を出すかである。
class CandidateJobApplicationTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct horse battery".freeze

  setup do
    @candidate = User.create!(email_address: "candidate@example.com", password: PASSWORD).tap(&:confirm)
    @candidate_profile = @candidate.create_candidate_profile!(display_name: "山田 太郎")

    recruiter = User.create!(email_address: "recruiter@example.com", password: PASSWORD).tap(&:confirm)
    @organization = Organization.create_with_owner!(name: "サンプル株式会社", user: recruiter)
    @job_posting = published_job_posting
  end

  test "未ログインでは応募を扱えない" do
    get profile_applications_path(locale: :ja)

    assert_redirected_to new_session_path(locale: :ja)
  end

  test "メールアドレスが未確認では応募を扱えない" do
    unconfirmed = User.create!(email_address: "unconfirmed@example.com", password: PASSWORD)
    sign_in_as(unconfirmed)

    get profile_applications_path(locale: :ja)

    assert_response :forbidden
  end

  test "プロフィールがないときは作成画面へ送る" do
    sign_in_as(User.create!(email_address: "no-profile@example.com", password: PASSWORD).tap(&:confirm))

    get profile_applications_path(locale: :ja)

    assert_redirected_to new_profile_path(locale: :ja)
  end

  test "自分の応募の一覧を見られる" do
    apply
    sign_in_as(@candidate)

    get profile_applications_path(locale: :ja)

    assert_response :success
    assert_select "main", text: /サンプルの求人/
  end

  test "一覧が新しい順に並ぶ" do
    apply
    apply(job_posting: published_job_posting(title: "あとから応募した求人"))
    sign_in_as(@candidate)

    get profile_applications_path(locale: :ja)

    assert_operator response.body.index("あとから応募した求人"), :<, response.body.index("サンプルの求人")
  end

  test "一覧と詳細は応募時点の写しを出す" do
    # 現在の求人の値を出すと、応募した覚えのない求人が並ぶ。
    job_application = apply
    @job_posting.update!(title: "書き換えた題名")
    sign_in_as(@candidate)

    get profile_applications_path(locale: :ja)

    assert_select "main", text: /サンプルの求人/
    assert_no_match(/書き換えた題名/, response.body)

    get profile_application_path(locale: :ja, id: job_application)

    assert_select "main h1", text: "サンプルの求人"
  end

  test "応募先の求人がいま公開中かどうかが分かる" do
    job_application = apply
    sign_in_as(@candidate)

    get profile_application_path(locale: :ja, id: job_application)

    assert_select "main", text: /#{I18n.t("candidate_job_applications.show.still_published")}/

    @job_posting.update!(status: "suspended")

    get profile_application_path(locale: :ja, id: job_application)

    assert_select "main", text: /#{I18n.t("candidate_job_applications.show.no_longer_published")}/
  end

  test "応募を取り消せる" do
    job_application = apply
    sign_in_as(@candidate)

    delete profile_application_path(locale: :ja, id: job_application)

    assert_redirected_to profile_applications_path(locale: :ja)
    assert_predicate job_application.reload, :withdrawn?
  end

  test "取り消した応募も一覧に残る" do
    # 消すと、企業側から見て「応募がなかったこと」になる。
    job_application = apply
    sign_in_as(@candidate)

    assert_no_difference -> { JobApplication.count } do
      delete profile_application_path(locale: :ja, id: job_application)
    end

    get profile_applications_path(locale: :ja)

    assert_select "main", text: /#{I18n.t("candidate_job_applications.index.statuses.withdrawn")}/
  end

  test "取り消した応募には取消の導線が出ない" do
    job_application = apply(status: "withdrawn")
    sign_in_as(@candidate)

    get profile_application_path(locale: :ja, id: job_application)

    assert_select "main form[method=post]", count: 0
  end

  test "取消の前に、応募し直せないことが伝わる" do
    job_application = apply
    sign_in_as(@candidate)

    get profile_application_path(locale: :ja, id: job_application)

    assert_select "main", text: /#{I18n.t("candidate_job_applications.show.withdraw_notice")}/
  end

  test "他人の応募を見られない" do
    others = other_profile
    others_application = others.job_applications.create!(job_posting: @job_posting)
    sign_in_as(@candidate)

    get profile_application_path(locale: :ja, id: others_application)

    assert_response :not_found
  end

  test "他人の応募を取り消せない" do
    others = other_profile
    others_application = others.job_applications.create!(job_posting: @job_posting)
    sign_in_as(@candidate)

    delete profile_application_path(locale: :ja, id: others_application)

    assert_response :not_found
    assert_predicate others_application.reload, :submitted?
  end

  test "応募の画面を日本語と英語で表示する" do
    job_application = apply
    sign_in_as(@candidate)

    I18n.available_locales.each do |locale|
      get profile_applications_path(locale: locale)

      assert_response :success
      assert_select "main h1", text: I18n.t("candidate_job_applications.index.title", locale: locale)

      get profile_application_path(locale: locale, id: job_application)

      assert_response :success
    end
  end

  private
    def sign_in_as(user)
      post session_path(locale: :ja), params: { email_address: user.email_address, password: PASSWORD }
    end

    def published_job_posting(title: "サンプルの求人")
      @organization.job_postings.create!(
        title: title, description: "仕事の内容", location: "東京", occupation: "人事",
        employment_type: "full_time", status: "published"
      )
    end

    def apply(job_posting: @job_posting, status: "submitted")
      @candidate_profile.job_applications.create!(job_posting: job_posting).tap do |job_application|
        job_application.update!(status: status) unless status == "submitted"
      end
    end

    def other_profile
      User.create!(email_address: "other@example.com", password: PASSWORD)
          .tap(&:confirm)
          .create_candidate_profile!(display_name: "他人の名前")
    end
end
