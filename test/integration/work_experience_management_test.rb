require "test_helper"

# 職歴の登録・編集・削除の契約を検証する。
#
# 検証対象は、誰がどの職歴を扱えるかである。
class WorkExperienceManagementTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct horse battery".freeze

  setup do
    @user = confirmed_user("member@example.com")
    @candidate_profile = @user.create_candidate_profile!(display_name: "山田 太郎")
  end

  test "未ログインでは職歴を扱えない" do
    get profile_work_experiences_path(locale: :ja)

    assert_redirected_to new_session_path(locale: :ja)
  end

  test "メールアドレスが未確認では職歴を扱えない" do
    unconfirmed = User.create!(email_address: "unconfirmed@example.com", password: PASSWORD)
    sign_in_as(unconfirmed)

    get profile_work_experiences_path(locale: :ja)

    assert_response :forbidden
  end

  test "プロフィールがないときは作成画面へ送る" do
    # 職歴の置き場所がない。
    other = confirmed_user("no-profile@example.com")
    sign_in_as(other)

    get profile_work_experiences_path(locale: :ja)

    assert_redirected_to new_profile_path(locale: :ja)
  end

  test "職歴を登録できる" do
    sign_in_as(@user)

    assert_difference -> { WorkExperience.count }, 1 do
      create_work_experience
    end

    assert_redirected_to profile_work_experiences_path(locale: :ja)
    assert_equal "株式会社サンプル", @candidate_profile.work_experiences.sole.organization_name
  end

  test "終了日を空欄にした職歴を登録できる" do
    sign_in_as(@user)

    create_work_experience(ended_on: "")

    assert_predicate @candidate_profile.work_experiences.sole, :current?
  end

  test "終了日が開始日より前だと登録できない" do
    sign_in_as(@user)

    assert_no_difference -> { WorkExperience.count } do
      create_work_experience(started_on: "2024-04-01", ended_on: "2024-03-31")
    end

    assert_response :unprocessable_content
  end

  test "未来の開始日だと登録できない" do
    sign_in_as(@user)

    assert_no_difference -> { WorkExperience.count } do
      create_work_experience(started_on: (Date.current + 1).to_s)
    end

    assert_response :unprocessable_content
  end

  test "職歴を編集できる" do
    sign_in_as(@user)
    work_experience = create_record

    patch profile_work_experience_path(locale: :ja, id: work_experience),
          params: { work_experience: { position: "採用担当" } }

    assert_redirected_to profile_work_experiences_path(locale: :ja)
    assert_equal "採用担当", work_experience.reload.position
  end

  test "職歴を削除できる" do
    sign_in_as(@user)
    work_experience = create_record

    assert_difference -> { WorkExperience.count }, -1 do
      delete profile_work_experience_path(locale: :ja, id: work_experience)
    end

    assert_redirected_to profile_work_experiences_path(locale: :ja)
  end

  test "一覧が開始日の新しい順に並ぶ" do
    sign_in_as(@user)
    create_record(organization_name: "古い会社", started_on: Date.new(2018, 4, 1))
    create_record(organization_name: "新しい会社", started_on: Date.new(2022, 4, 1))

    get profile_work_experiences_path(locale: :ja)

    assert_response :success
    assert_operator response.body.index("新しい会社"), :<, response.body.index("古い会社")
  end

  test "在籍中かどうかが一覧から分かる" do
    # 終了日の空欄を空欄のまま出すと、在籍中か書き忘れかが読み手に分からない。
    sign_in_as(@user)
    create_record(ended_on: nil)

    get profile_work_experiences_path(locale: :ja)

    assert_select "main li", text: /在籍中/
  end

  test "他のアカウントの職歴を編集できない" do
    other = confirmed_user("other@example.com")
    other_profile = other.create_candidate_profile!(display_name: "他人の名前")
    others_work_experience = other_profile.work_experiences.create!(
      organization_name: "他人の会社", position: "人事", started_on: Date.new(2020, 4, 1)
    )
    sign_in_as(@user)

    patch profile_work_experience_path(locale: :ja, id: others_work_experience),
          params: { work_experience: { position: "書き換え" } }

    assert_response :not_found
    assert_equal "人事", others_work_experience.reload.position
  end

  test "他のアカウントの職歴を削除できない" do
    other = confirmed_user("other@example.com")
    other_profile = other.create_candidate_profile!(display_name: "他人の名前")
    others_work_experience = other_profile.work_experiences.create!(
      organization_name: "他人の会社", position: "人事", started_on: Date.new(2020, 4, 1)
    )
    sign_in_as(@user)

    assert_no_difference -> { WorkExperience.count } do
      delete profile_work_experience_path(locale: :ja, id: others_work_experience)
    end

    assert_response :not_found
  end

  test "一覧と追加と編集の画面を日本語と英語で表示する" do
    sign_in_as(@user)
    work_experience = create_record

    I18n.available_locales.each do |locale|
      get profile_work_experiences_path(locale: locale)

      assert_response :success
      assert_select "main h1", text: I18n.t("work_experiences.index.title", locale: locale)

      get new_profile_work_experience_path(locale: locale)

      assert_response :success
      assert_select "main h1", text: I18n.t("work_experiences.new.title", locale: locale)

      get edit_profile_work_experience_path(locale: locale, id: work_experience)

      assert_response :success
      assert_select "main h1", text: I18n.t("work_experiences.edit.title", locale: locale)
    end
  end

  private
    def confirmed_user(email_address)
      User.create!(email_address: email_address, password: PASSWORD).tap(&:confirm)
    end

    def sign_in_as(user)
      post session_path(locale: :ja), params: { email_address: user.email_address, password: PASSWORD }
    end

    def create_work_experience(**overrides)
      post profile_work_experiences_path(locale: :ja),
           params: { work_experience: {
             organization_name: "株式会社サンプル",
             position: "人事",
             started_on: "2020-04-01"
           }.merge(overrides) }
    end

    def create_record(**overrides)
      @candidate_profile.work_experiences.create!({
        organization_name: "株式会社サンプル",
        position: "人事",
        started_on: Date.new(2020, 4, 1)
      }.merge(overrides))
    end
end
