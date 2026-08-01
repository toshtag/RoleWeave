require "test_helper"

# プロフィールの作成と編集の契約を検証する。
#
# 検証対象は、誰がどのプロフィールを扱えるかである。
class CandidateProfileManagementTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct horse battery".freeze

  setup do
    @user = confirmed_user("member@example.com")
  end

  test "未ログインではプロフィールを扱えない" do
    get profile_path(locale: :ja)

    assert_redirected_to new_session_path(locale: :ja)
  end

  test "メールアドレスが未確認ではプロフィールを扱えない" do
    unconfirmed = User.create!(email_address: "unconfirmed@example.com", password: PASSWORD)
    sign_in_as(unconfirmed)

    get profile_path(locale: :ja)

    assert_response :forbidden
  end

  test "プロフィールがないときは作成画面へ送る" do
    # 空の詳細を見せても、次に何をすればよいかが伝わらない。
    sign_in_as(@user)

    get profile_path(locale: :ja)

    assert_redirected_to new_profile_path(locale: :ja)
  end

  test "プロフィールを作成できる" do
    sign_in_as(@user)

    assert_difference -> { CandidateProfile.count }, 1 do
      create_profile
    end

    assert_redirected_to profile_path(locale: :ja)
    assert_equal "山田 太郎", @user.reload.candidate_profile.display_name
  end

  test "表示名が空だと作成できない" do
    sign_in_as(@user)

    assert_no_difference -> { CandidateProfile.count } do
      create_profile(display_name: "  ")
    end

    assert_response :unprocessable_content
  end

  test "作成済みなら作成画面から詳細へ送る" do
    sign_in_as(@user)
    create_profile

    get new_profile_path(locale: :ja)

    assert_redirected_to profile_path(locale: :ja)
  end

  test "プロフィールを編集できる" do
    sign_in_as(@user)
    create_profile

    patch profile_path(locale: :ja), params: { candidate_profile: { display_name: "山田 花子" } }

    assert_redirected_to profile_path(locale: :ja)
    assert_equal "山田 花子", @user.reload.candidate_profile.display_name
  end

  test "詳細に入力した項目が出る" do
    sign_in_as(@user)
    create_profile(location: "東京", desired_occupation: "人事", introduction: "採用の実務を担当してきました。")

    get profile_path(locale: :ja)

    assert_response :success
    assert_select "main dd", text: "東京"
    assert_select "main dd", text: "人事"
    assert_select "main", text: /採用の実務を担当してきました。/
  end

  test "未入力の項目は詳細に出ない" do
    sign_in_as(@user)
    create_profile

    get profile_path(locale: :ja)

    # 表示名の 1 行だけが出る。
    assert_select "main dd", count: 1
    # 自己紹介の見出しは、書かれていなければ出さない。
    assert_select "main h2", text: CandidateProfile.human_attribute_name(:introduction), count: 0
  end

  test "他のアカウントのプロフィールへ到達する経路がない" do
    # 経路が ID を受け取らないため、他人のプロフィールを指す方法がない。
    other = confirmed_user("other@example.com")
    other.create_candidate_profile!(display_name: "他人の名前")
    sign_in_as(@user)

    get profile_path(locale: :ja)

    assert_redirected_to new_profile_path(locale: :ja)
    assert_not_includes Rails.application.routes.routes.map { |route| route.path.spec.to_s },
                        "/:locale/profiles/:id(.:format)"
  end

  test "作成と編集の画面を日本語と英語で表示する" do
    sign_in_as(@user)

    I18n.available_locales.each do |locale|
      get new_profile_path(locale: locale)

      assert_response :success
      assert_select "main h1", text: I18n.t("candidate_profiles.new.title", locale: locale)
    end

    create_profile

    I18n.available_locales.each do |locale|
      get edit_profile_path(locale: locale)

      assert_response :success
      assert_select "main h1", text: I18n.t("candidate_profiles.edit.title", locale: locale)
    end
  end

  private
    def confirmed_user(email_address)
      User.create!(email_address: email_address, password: PASSWORD).tap(&:confirm)
    end

    def sign_in_as(user)
      post session_path(locale: :ja), params: { email_address: user.email_address, password: PASSWORD }
    end

    def create_profile(display_name: "山田 太郎", **overrides)
      post profile_path(locale: :ja),
           params: { candidate_profile: { display_name: display_name }.merge(overrides) }
    end
end
