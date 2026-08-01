require "test_helper"

# プロフィールの公開範囲の契約を検証する。
#
# 検証対象は、どの設定のときに誰から見えるかである。
# ここが緩むと、個人情報がそのまま企業側へ出る。
class ProfileVisibilityTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct horse battery".freeze

  setup do
    @candidate = confirmed_user("candidate@example.com")
    @candidate_profile = @candidate.create_candidate_profile!(display_name: "山田 太郎")

    @recruiter = confirmed_user("recruiter@example.com")
    @organization = Organization.create_with_owner!(name: "サンプル株式会社", user: @recruiter)
  end

  test "新しいプロフィールは誰にも見せない設定で始まる" do
    # 設定を忘れたまま見えることがないようにする。
    assert_equal "closed", @candidate_profile.visibility
    assert_not_predicate @candidate_profile, :desired_salary_visible?
  end

  test "値の一覧にない公開範囲を拒否する" do
    assert_not @candidate_profile.update(visibility: "everyone")
  end

  test "誰にも見せない設定のプロフィールは企業から見えない" do
    sign_in_as(@recruiter)

    get organization_candidate_profile_path(locale: :ja, organization_id: @organization, id: @candidate_profile)

    assert_response :not_found
  end

  test "応募した企業にだけ見せる設定でも、この時点では見えない" do
    # 応募の仕組みがまだないため、誰にも見えない。実装漏れではない。
    @candidate_profile.update!(visibility: "applied_organizations")
    sign_in_as(@recruiter)

    get organization_candidate_profile_path(locale: :ja, organization_id: @organization, id: @candidate_profile)

    assert_response :not_found
  end

  test "すべての企業に見せる設定のプロフィールは所属者から見える" do
    @candidate_profile.update!(visibility: "all_organizations")
    sign_in_as(@recruiter)

    get organization_candidate_profile_path(locale: :ja, organization_id: @organization, id: @candidate_profile)

    assert_response :success
    assert_select "main h1", text: "山田 太郎"
  end

  test "組織に所属しない利用者からは見えない" do
    @candidate_profile.update!(visibility: "all_organizations")
    outsider = confirmed_user("outsider@example.com")
    sign_in_as(outsider)

    get organization_candidate_profile_path(locale: :ja, organization_id: @organization, id: @candidate_profile)

    assert_response :not_found
  end

  test "未ログインでは企業側の経路を使えない" do
    @candidate_profile.update!(visibility: "all_organizations")

    get organization_candidate_profile_path(locale: :ja, organization_id: @organization, id: @candidate_profile)

    assert_redirected_to new_session_path(locale: :ja)
  end

  test "メールアドレスが未確認では企業側の経路を使えない" do
    @candidate_profile.update!(visibility: "all_organizations")
    unconfirmed = User.create!(email_address: "unconfirmed@example.com", password: PASSWORD)
    Membership.create!(organization: @organization, user: unconfirmed, role: "member")
    sign_in_as(unconfirmed)

    get organization_candidate_profile_path(locale: :ja, organization_id: @organization, id: @candidate_profile)

    assert_response :forbidden
  end

  test "職歴・学歴・スキルも同じ公開範囲に従う" do
    fill_profile
    sign_in_as(@recruiter)

    get organization_candidate_profile_path(locale: :ja, organization_id: @organization, id: @candidate_profile)

    assert_response :not_found

    @candidate_profile.update!(visibility: "all_organizations")

    get organization_candidate_profile_path(locale: :ja, organization_id: @organization, id: @candidate_profile)

    assert_response :success
    assert_select "main", text: /株式会社サンプル/
    assert_select "main", text: /サンプル大学/
    assert_select "main", text: /Ruby/
  end

  test "希望年収は見せる設定のときだけ企業側に出る" do
    fill_profile
    @candidate_profile.update!(visibility: "all_organizations")
    sign_in_as(@recruiter)

    get organization_candidate_profile_path(locale: :ja, organization_id: @organization, id: @candidate_profile)

    assert_response :success
    assert_select "main dd", text: /5,000,000/, count: 0

    @candidate_profile.update!(desired_salary_visible: true)

    get organization_candidate_profile_path(locale: :ja, organization_id: @organization, id: @candidate_profile)

    assert_select "main dd", text: /5,000,000/
  end

  test "企業側の詳細は検索へ出さない" do
    @candidate_profile.update!(visibility: "all_organizations")
    sign_in_as(@recruiter)

    get organization_candidate_profile_path(locale: :ja, organization_id: @organization, id: @candidate_profile)

    assert_select "meta[name=?][content=?]", "robots", "noindex, nofollow"
  end

  test "候補者の一覧・検索の経路がない" do
    # 一覧があること自体が、公開範囲を「探されてよい」という意味へ変えてしまう。
    paths = Rails.application.routes.routes.map { |route| route.path.spec.to_s }

    assert_not_includes paths, "/:locale/organizations/:organization_id/candidate_profiles(.:format)"
  end

  test "本人が公開範囲を変更できる" do
    sign_in_as(@candidate)

    patch profile_visibility_path(locale: :ja),
          params: { candidate_profile: { visibility: "all_organizations", desired_salary_visible: "1" } }

    assert_redirected_to profile_path(locale: :ja)
    assert_equal "all_organizations", @candidate_profile.reload.visibility
    assert_predicate @candidate_profile, :desired_salary_visible?
  end

  test "値の一覧にない公開範囲を保存できない" do
    sign_in_as(@candidate)

    patch profile_visibility_path(locale: :ja), params: { candidate_profile: { visibility: "everyone" } }

    assert_response :unprocessable_content
    assert_equal "closed", @candidate_profile.reload.visibility
  end

  test "他人の公開範囲を変えられない" do
    # 経路が ID を受け取らないため、対象は常に自分のプロフィールになる。
    other = confirmed_user("other@example.com")
    other_profile = other.create_candidate_profile!(display_name: "他人の名前")
    sign_in_as(@candidate)

    patch profile_visibility_path(locale: :ja), params: { candidate_profile: { visibility: "all_organizations" } }

    assert_equal "closed", other_profile.reload.visibility
    assert_equal "all_organizations", @candidate_profile.reload.visibility
  end

  test "公開範囲の画面を日本語と英語で表示する" do
    sign_in_as(@candidate)

    I18n.available_locales.each do |locale|
      get edit_profile_visibility_path(locale: locale)

      assert_response :success
      assert_select "main h1", text: I18n.t("profile_visibilities.edit.title", locale: locale)
    end
  end

  private
    def confirmed_user(email_address)
      User.create!(email_address: email_address, password: PASSWORD).tap(&:confirm)
    end

    def sign_in_as(user)
      post session_path(locale: :ja), params: { email_address: user.email_address, password: PASSWORD }
    end

    def fill_profile
      @candidate_profile.work_experiences.create!(
        organization_name: "株式会社サンプル", position: "人事", started_on: Date.new(2020, 4, 1)
      )
      @candidate_profile.educations.create!(school_name: "サンプル大学", started_on: Date.new(2016, 4, 1))
      @candidate_profile.skills.create!(name: "Ruby")
      @candidate_profile.create_desired_condition!(salary_currency: "JPY", annual_salary_min: 5_000_000)
    end
end
