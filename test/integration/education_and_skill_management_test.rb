require "test_helper"

# 学歴とスキルの登録・編集・削除の契約を検証する。
#
# 検証対象は、誰がどの学歴・スキルを扱えるかである。
class EducationAndSkillManagementTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct horse battery".freeze

  setup do
    @user = confirmed_user("member@example.com")
    @candidate_profile = @user.create_candidate_profile!(display_name: "山田 太郎")
  end

  test "未ログインでは学歴もスキルも扱えない" do
    [ profile_educations_path(locale: :ja), profile_skills_path(locale: :ja) ].each do |path|
      get path

      assert_redirected_to new_session_path(locale: :ja)
    end
  end

  test "メールアドレスが未確認では学歴もスキルも扱えない" do
    unconfirmed = User.create!(email_address: "unconfirmed@example.com", password: PASSWORD)
    sign_in_as(unconfirmed)

    [ profile_educations_path(locale: :ja), profile_skills_path(locale: :ja) ].each do |path|
      get path

      assert_response :forbidden
    end
  end

  test "プロフィールがないときは作成画面へ送る" do
    sign_in_as(confirmed_user("no-profile@example.com"))

    [ profile_educations_path(locale: :ja), profile_skills_path(locale: :ja) ].each do |path|
      get path

      assert_redirected_to new_profile_path(locale: :ja)
    end
  end

  test "学歴を登録できる" do
    sign_in_as(@user)

    assert_difference -> { Education.count }, 1 do
      post profile_educations_path(locale: :ja),
           params: { education: { school_name: "サンプル大学", started_on: "2016-04-01" } }
    end

    assert_redirected_to profile_educations_path(locale: :ja)
    assert_equal "サンプル大学", @candidate_profile.educations.sole.school_name
  end

  test "卒業日が入学日より前だと学歴を登録できない" do
    sign_in_as(@user)

    assert_no_difference -> { Education.count } do
      post profile_educations_path(locale: :ja),
           params: { education: { school_name: "サンプル大学", started_on: "2016-04-01", ended_on: "2016-03-31" } }
    end

    assert_response :unprocessable_content
  end

  test "学歴を編集して削除できる" do
    sign_in_as(@user)
    education = create_education

    patch profile_education_path(locale: :ja, id: education),
          params: { education: { field_of_study: "経営学" } }

    assert_redirected_to profile_educations_path(locale: :ja)
    assert_equal "経営学", education.reload.field_of_study

    assert_difference -> { Education.count }, -1 do
      delete profile_education_path(locale: :ja, id: education)
    end
  end

  test "在学中かどうかが学歴の一覧から分かる" do
    sign_in_as(@user)
    create_education(ended_on: nil)

    get profile_educations_path(locale: :ja)

    assert_select "main li", text: /在学中/
  end

  test "学歴の一覧が入学日の新しい順に並ぶ" do
    sign_in_as(@user)
    create_education(school_name: "古い学校", started_on: Date.new(2012, 4, 1))
    create_education(school_name: "新しい学校", started_on: Date.new(2016, 4, 1))

    get profile_educations_path(locale: :ja)

    assert_operator response.body.index("新しい学校"), :<, response.body.index("古い学校")
  end

  test "スキルを登録できる" do
    sign_in_as(@user)

    assert_difference -> { Skill.count }, 1 do
      post profile_skills_path(locale: :ja), params: { skill: { name: "Ruby", years_of_experience: 5 } }
    end

    assert_redirected_to profile_skills_path(locale: :ja)
    assert_equal 5, @candidate_profile.skills.sole.years_of_experience
  end

  test "同じ名前のスキルを 2 つ登録できない" do
    sign_in_as(@user)
    create_skill(name: "Ruby")

    assert_no_difference -> { Skill.count } do
      post profile_skills_path(locale: :ja), params: { skill: { name: "Ruby" } }
    end

    assert_response :unprocessable_content
  end

  test "負の経験年数だとスキルを登録できない" do
    sign_in_as(@user)

    assert_no_difference -> { Skill.count } do
      post profile_skills_path(locale: :ja), params: { skill: { name: "Ruby", years_of_experience: -1 } }
    end

    assert_response :unprocessable_content
  end

  test "スキルを編集して削除できる" do
    sign_in_as(@user)
    skill = create_skill

    patch profile_skill_path(locale: :ja, id: skill), params: { skill: { years_of_experience: 3 } }

    assert_redirected_to profile_skills_path(locale: :ja)
    assert_equal 3, skill.reload.years_of_experience

    assert_difference -> { Skill.count }, -1 do
      delete profile_skill_path(locale: :ja, id: skill)
    end
  end

  test "スキルの一覧が名前の昇順に並ぶ" do
    sign_in_as(@user)
    create_skill(name: "Ruby")
    create_skill(name: "Docker")

    get profile_skills_path(locale: :ja)

    assert_operator response.body.index("Docker"), :<, response.body.index("Ruby")
  end

  test "経験年数が未入力のスキルには年数を出さない" do
    # 未入力の行に 0 年と出すと、事実と違う。
    sign_in_as(@user)
    create_skill(years_of_experience: nil)

    get profile_skills_path(locale: :ja)

    assert_select "main li", text: /経験/, count: 0
  end

  test "他のアカウントの学歴とスキルを編集できない" do
    others = other_profile
    others_education = others.educations.create!(school_name: "他人の学校", started_on: Date.new(2016, 4, 1))
    others_skill = others.skills.create!(name: "他人のスキル")
    sign_in_as(@user)

    patch profile_education_path(locale: :ja, id: others_education),
          params: { education: { school_name: "書き換え" } }

    assert_response :not_found
    assert_equal "他人の学校", others_education.reload.school_name

    patch profile_skill_path(locale: :ja, id: others_skill), params: { skill: { name: "書き換え" } }

    assert_response :not_found
    assert_equal "他人のスキル", others_skill.reload.name
  end

  test "他のアカウントの学歴とスキルを削除できない" do
    others = other_profile
    others_education = others.educations.create!(school_name: "他人の学校", started_on: Date.new(2016, 4, 1))
    others_skill = others.skills.create!(name: "他人のスキル")
    sign_in_as(@user)

    assert_no_difference -> { Education.count + Skill.count } do
      delete profile_education_path(locale: :ja, id: others_education)

      assert_response :not_found

      delete profile_skill_path(locale: :ja, id: others_skill)

      assert_response :not_found
    end
  end

  test "学歴とスキルの画面を日本語と英語で表示する" do
    sign_in_as(@user)
    education = create_education
    skill = create_skill

    I18n.available_locales.each do |locale|
      {
        "educations.index.title" => profile_educations_path(locale: locale),
        "educations.new.title" => new_profile_education_path(locale: locale),
        "educations.edit.title" => edit_profile_education_path(locale: locale, id: education),
        "skills.index.title" => profile_skills_path(locale: locale),
        "skills.new.title" => new_profile_skill_path(locale: locale),
        "skills.edit.title" => edit_profile_skill_path(locale: locale, id: skill)
      }.each do |key, path|
        get path

        assert_response :success
        assert_select "main h1", text: I18n.t(key, locale: locale)
      end
    end
  end

  private
    def confirmed_user(email_address)
      User.create!(email_address: email_address, password: PASSWORD).tap(&:confirm)
    end

    def sign_in_as(user)
      post session_path(locale: :ja), params: { email_address: user.email_address, password: PASSWORD }
    end

    def other_profile
      confirmed_user("other@example.com").create_candidate_profile!(display_name: "他人の名前")
    end

    def create_education(**overrides)
      @candidate_profile.educations.create!({
        school_name: "サンプル大学", started_on: Date.new(2016, 4, 1)
      }.merge(overrides))
    end

    def create_skill(**overrides)
      @candidate_profile.skills.create!({ name: "Ruby", years_of_experience: 5 }.merge(overrides))
    end
end
