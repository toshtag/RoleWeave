require "test_helper"

# 希望条件の編集と、応募に必要な項目の確認の契約を検証する。
#
# 検証対象は、誰が扱えるかと、画面が何を示すかである。
class DesiredConditionManagementTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct horse battery".freeze

  setup do
    @user = confirmed_user("member@example.com")
    @candidate_profile = @user.create_candidate_profile!(display_name: "山田 太郎")
  end

  test "未ログインでは希望条件を扱えない" do
    get edit_profile_desired_condition_path(locale: :ja)

    assert_redirected_to new_session_path(locale: :ja)
  end

  test "メールアドレスが未確認では希望条件を扱えない" do
    unconfirmed = User.create!(email_address: "unconfirmed@example.com", password: PASSWORD)
    sign_in_as(unconfirmed)

    get edit_profile_desired_condition_path(locale: :ja)

    assert_response :forbidden
  end

  test "プロフィールがないときは作成画面へ送る" do
    sign_in_as(confirmed_user("no-profile@example.com"))

    get edit_profile_desired_condition_path(locale: :ja)

    assert_redirected_to new_profile_path(locale: :ja)
  end

  test "まだない希望条件も同じ編集画面から書ける" do
    # 作成と編集を分けると、同じ操作が 2 つの入口を持つことになる。
    sign_in_as(@user)

    get edit_profile_desired_condition_path(locale: :ja)

    assert_response :success
  end

  test "希望条件を保存できる" do
    sign_in_as(@user)

    assert_difference -> { DesiredCondition.count }, 1 do
      update_desired_condition(employment_type: "full_time", location: "東京")
    end

    assert_redirected_to profile_path(locale: :ja)
    assert_equal "東京", @candidate_profile.reload.desired_condition.location
  end

  test "2 回保存しても希望条件は 1 つのまま" do
    sign_in_as(@user)
    update_desired_condition(location: "東京")

    assert_no_difference -> { DesiredCondition.count } do
      update_desired_condition(location: "大阪")
    end

    assert_equal "大阪", @candidate_profile.reload.desired_condition.location
  end

  test "通貨のない希望年収を保存できない" do
    sign_in_as(@user)

    assert_no_difference -> { DesiredCondition.count } do
      update_desired_condition(annual_salary_min: 5_000_000)
    end

    assert_response :unprocessable_content
  end

  test "語彙にない雇用形態を保存できない" do
    sign_in_as(@user)

    assert_no_difference -> { DesiredCondition.count } do
      update_desired_condition(employment_type: "volunteer")
    end

    assert_response :unprocessable_content
  end

  test "希望条件が詳細に出る" do
    sign_in_as(@user)
    update_desired_condition(employment_type: "full_time", salary_currency: "JPY",
                             annual_salary_min: 5_000_000)

    get profile_path(locale: :ja)

    assert_response :success
    assert_select "main dd", text: /5,000,000/
  end

  test "そろっていない項目を名前で示す" do
    sign_in_as(@user)

    get profile_path(locale: :ja)

    assert_select "main li", text: I18n.t("candidate_profiles.show.completeness_items.work_experience")
    assert_select "main li", text: I18n.t("candidate_profiles.show.completeness_items.desired_condition")
  end

  test "完成度を割合や点数として出さない" do
    # 割合で出すと、応募に不要な個人情報まで書かせる圧力になる。
    sign_in_as(@user)

    get profile_path(locale: :ja)

    assert_no_match(/\d+\s*%/, response.body)
    assert_no_match(%r{\d+\s*/\s*5}, response.body)
  end

  test "すべて書くとそろったと示す" do
    sign_in_as(@user)
    fill_everything

    get profile_path(locale: :ja)

    assert_select "main", text: /#{I18n.t("candidate_profiles.show.completeness_complete")}/
  end

  test "他のアカウントの希望条件へ到達する経路がない" do
    other = confirmed_user("other@example.com")
    other_profile = other.create_candidate_profile!(display_name: "他人の名前")
    other_profile.create_desired_condition!(location: "他人の希望")
    sign_in_as(@user)

    update_desired_condition(location: "東京")

    assert_equal "他人の希望", other_profile.reload.desired_condition.location
    assert_equal "東京", @candidate_profile.reload.desired_condition.location
  end

  test "希望条件の画面を日本語と英語で表示する" do
    sign_in_as(@user)

    I18n.available_locales.each do |locale|
      get edit_profile_desired_condition_path(locale: locale)

      assert_response :success
      assert_select "main h1", text: I18n.t("desired_conditions.edit.title", locale: locale)
    end
  end

  private
    def confirmed_user(email_address)
      User.create!(email_address: email_address, password: PASSWORD).tap(&:confirm)
    end

    def sign_in_as(user)
      post session_path(locale: :ja), params: { email_address: user.email_address, password: PASSWORD }
    end

    def update_desired_condition(**overrides)
      patch profile_desired_condition_path(locale: :ja), params: { desired_condition: overrides }
    end

    def fill_everything
      @candidate_profile.update!(introduction: "採用の実務を担当してきました。")
      @candidate_profile.work_experiences.create!(
        organization_name: "株式会社サンプル", position: "人事", started_on: Date.new(2020, 4, 1)
      )
      @candidate_profile.educations.create!(school_name: "サンプル大学", started_on: Date.new(2016, 4, 1))
      @candidate_profile.skills.create!(name: "Ruby")
      update_desired_condition(employment_type: "full_time")
    end
end
