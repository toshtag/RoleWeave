require "test_helper"

# 保存の経路の契約を検証する。
class SavedSearchRequestTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct horse battery".freeze

  setup do
    @candidate = User.create!(email_address: "candidate@example.com", password: PASSWORD).tap(&:confirm)
    @profile = @candidate.create_candidate_profile!(display_name: "山田 太郎")

    owner = User.create!(email_address: "owner@example.com", password: PASSWORD).tap(&:confirm)
    @organization = Organization.create_with_owner!(name: "サンプル株式会社", user: owner)
    @job_posting = published_job_posting
  end

  test "未ログインでは保存を扱えない" do
    get profile_saved_jobs_path(locale: :ja)

    assert_redirected_to new_session_path(locale: :ja)
  end

  test "求人を保存して一覧で見られる" do
    sign_in_as(@candidate)

    assert_difference -> { SavedJobPosting.count }, 1 do
      post profile_saved_jobs_path(locale: :ja, job_posting_id: @job_posting)
    end

    get profile_saved_jobs_path(locale: :ja)

    assert_select "main", text: /サンプルの求人/
  end

  test "公開中でない求人は保存できない" do
    draft = @organization.job_postings.create!(title: "下書き", description: "本文", status: "draft")
    sign_in_as(@candidate)

    post profile_saved_jobs_path(locale: :ja, job_posting_id: draft)

    assert_response :not_found
  end

  test "保存を外せる" do
    saved = @profile.saved_job_postings.create!(job_posting: @job_posting)
    sign_in_as(@candidate)

    assert_difference -> { SavedJobPosting.count }, -1 do
      delete profile_saved_job_path(locale: :ja, id: saved)
    end
  end

  test "他人の保存を外せない" do
    other = User.create!(email_address: "other@example.com", password: PASSWORD).tap(&:confirm)
    other_profile = other.create_candidate_profile!(display_name: "他人の名前")
    others_saved = other_profile.saved_job_postings.create!(job_posting: @job_posting)
    sign_in_as(@candidate)

    delete profile_saved_job_path(locale: :ja, id: others_saved)

    assert_response :not_found
    assert SavedJobPosting.exists?(others_saved.id)
  end

  test "検索条件を保存して再実行できる" do
    sign_in_as(@candidate)

    post profile_saved_searches_path(locale: :ja), params: { name: "人事の求人", occupation: "人事" }

    saved_search = SavedSearch.sole

    assert_equal "人事の求人", saved_search.name
    assert_equal({ "occupation" => "人事" }, saved_search.conditions)

    get profile_saved_searches_path(locale: :ja)

    assert_select "main a", text: "人事の求人"
  end

  test "検索が使わない項目は保存されない" do
    sign_in_as(@candidate)

    post profile_saved_searches_path(locale: :ja), params: { name: "条件", secret: "x", keyword: "開発" }

    assert_equal({ "keyword" => "開発" }, SavedSearch.sole.conditions)
  end

  test "通知の設定を切り替えられる" do
    saved_search = @profile.saved_searches.create!(name: "すべて", conditions: {})
    sign_in_as(@candidate)

    patch profile_saved_search_path(locale: :ja, id: saved_search), params: { notify: "0" }

    assert_not saved_search.reload.notify
  end

  test "保存した求人が公開でなくなったことが一覧で分かる" do
    @profile.saved_job_postings.create!(job_posting: @job_posting)
    @job_posting.update!(status: "suspended")
    sign_in_as(@candidate)

    get profile_saved_jobs_path(locale: :ja)

    assert_select "main", text: /#{I18n.t("saved_job_postings.index.no_longer_published")}/
  end

  test "求人の詳細と一覧に保存の導線がある" do
    get public_job_posting_path(locale: :ja, id: @job_posting)

    assert_select "main", text: /#{I18n.t("public.job_postings.show.save")}/

    get public_job_postings_path(locale: :ja)

    # 送信ボタンの文言は value 属性に入る。
    assert_select "main input[type=submit][value=?]", I18n.t("public.job_postings.index.save_search")
  end

  test "保存の画面を日本語と英語で表示する" do
    sign_in_as(@candidate)

    I18n.available_locales.each do |locale|
      get profile_saved_jobs_path(locale: locale)

      assert_response :success
      assert_select "main h1", text: I18n.t("saved_job_postings.index.title", locale: locale)

      get profile_saved_searches_path(locale: locale)

      assert_response :success
      assert_select "main h1", text: I18n.t("saved_searches.index.title", locale: locale)
    end
  end

  private
    def sign_in_as(user)
      post session_path(locale: :ja), params: { email_address: user.email_address, password: PASSWORD }
    end

    def published_job_posting(title: "サンプルの求人")
      @organization.job_postings.create!(
        title: title, description: "仕事の内容", occupation: "人事", status: "published"
      )
    end
end
