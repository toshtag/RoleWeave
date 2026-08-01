require "test_helper"

# 応募の経路の契約を検証する。
#
# 検証対象は、誰が何へ応募できるかと、応募の前に何を伝えるかである。
class JobApplicationRequestTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct horse battery".freeze

  setup do
    @candidate = User.create!(email_address: "candidate@example.com", password: PASSWORD).tap(&:confirm)
    @candidate_profile = @candidate.create_candidate_profile!(display_name: "山田 太郎")

    recruiter = User.create!(email_address: "recruiter@example.com", password: PASSWORD).tap(&:confirm)
    @organization = Organization.create_with_owner!(name: "サンプル株式会社", user: recruiter)
    @job_posting = published_job_posting
  end

  test "求人の詳細に応募の導線が出る" do
    # 未ログインでも出す。出さないと、応募できることが分からないまま画面を離れる。
    get public_job_posting_path(locale: :ja, id: @job_posting)

    assert_select "main a[href=?]",
                  new_public_job_posting_application_path(locale: :ja, public_job_posting_id: @job_posting)
  end

  test "未ログインでは応募できない" do
    post public_job_posting_application_path(locale: :ja, public_job_posting_id: @job_posting)

    assert_redirected_to new_session_path(locale: :ja)
    assert_equal 0, JobApplication.count
  end

  test "メールアドレスが未確認では応募できない" do
    unconfirmed = User.create!(email_address: "unconfirmed@example.com", password: PASSWORD)
    unconfirmed.create_candidate_profile!(display_name: "未確認 太郎")
    sign_in_as(unconfirmed)

    post public_job_posting_application_path(locale: :ja, public_job_posting_id: @job_posting)

    assert_response :forbidden
    assert_equal 0, JobApplication.count
  end

  test "プロフィールがない状態では応募できない" do
    no_profile = User.create!(email_address: "no-profile@example.com", password: PASSWORD).tap(&:confirm)
    sign_in_as(no_profile)

    get new_public_job_posting_application_path(locale: :ja, public_job_posting_id: @job_posting)

    assert_redirected_to new_profile_path(locale: :ja)
  end

  test "応募の確認画面に、送られる内容が出る" do
    @candidate_profile.skills.create!(name: "Ruby")
    sign_in_as(@candidate)

    get new_public_job_posting_application_path(locale: :ja, public_job_posting_id: @job_posting)

    assert_response :success
    assert_select "main", text: /山田 太郎/
    assert_select "main", text: /#{I18n.t("job_applications.new.snapshot_notice")}/
  end

  test "希望年収を送るかどうかが確認画面に出る" do
    sign_in_as(@candidate)

    get new_public_job_posting_application_path(locale: :ja, public_job_posting_id: @job_posting)

    assert_select "main", text: /#{I18n.t("job_applications.new.desired_salary_excluded")}/

    @candidate_profile.update!(desired_salary_visible: true)

    get new_public_job_posting_application_path(locale: :ja, public_job_posting_id: @job_posting)

    assert_select "main", text: /#{I18n.t("job_applications.new.desired_salary_included")}/
  end

  test "公開中の求人へ応募できる" do
    sign_in_as(@candidate)

    assert_difference -> { JobApplication.count }, 1 do
      post public_job_posting_application_path(locale: :ja, public_job_posting_id: @job_posting)
    end

    assert_redirected_to public_job_posting_path(locale: :ja, id: @job_posting)
    assert_equal @job_posting, @candidate_profile.job_applications.sole.job_posting
  end

  test "公開中でない求人へは応募できない" do
    draft = @organization.job_postings.create!(title: "下書きの求人", description: "本文", status: "draft")
    sign_in_as(@candidate)

    post public_job_posting_application_path(locale: :ja, public_job_posting_id: draft)

    assert_response :not_found
    assert_equal 0, JobApplication.count
  end

  test "同じ求人へ 2 回応募できない" do
    sign_in_as(@candidate)
    post public_job_posting_application_path(locale: :ja, public_job_posting_id: @job_posting)

    assert_no_difference -> { JobApplication.count } do
      post public_job_posting_application_path(locale: :ja, public_job_posting_id: @job_posting)
    end

    assert_response :unprocessable_content
  end

  test "他人のプロフィールから応募する経路がない" do
    # 応募元は経路から受け取らず、常にログインしている本人のプロフィールとする。
    # 「最初のプロフィール」を使う実装になっていないことを、
    # 後から作った側でログインして確かめる。
    later = User.create!(email_address: "later@example.com", password: PASSWORD).tap(&:confirm)
    later_profile = later.create_candidate_profile!(display_name: "後から登録した人")
    sign_in_as(later)

    post public_job_posting_application_path(locale: :ja, public_job_posting_id: @job_posting)

    assert_equal 1, later_profile.job_applications.count
    assert_equal 0, @candidate_profile.job_applications.count
  end

  test "応募の画面を日本語と英語で表示する" do
    sign_in_as(@candidate)

    I18n.available_locales.each do |locale|
      get new_public_job_posting_application_path(locale: locale, public_job_posting_id: @job_posting)

      assert_response :success
      assert_select "main h1",
                    text: I18n.t("job_applications.new.title", title: @job_posting.title, locale: locale)
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
end
