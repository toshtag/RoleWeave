require "test_helper"

# プロフィールとアカウントの削除の経路の契約を検証する。
#
# 検証対象は、誰が何を消せるかと、消す前に何を確かめるかである。
class AccountDeletionRequestTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct horse battery".freeze

  setup do
    @user = User.create!(email_address: "member@example.com", password: PASSWORD).tap(&:confirm)
  end

  test "未ログインでは削除の画面を開けない" do
    get account_deletion_path(locale: :ja)

    assert_redirected_to new_session_path(locale: :ja)
  end

  test "メールアドレスが未確認では削除できない" do
    unconfirmed = User.create!(email_address: "unconfirmed@example.com", password: PASSWORD)
    sign_in_as(unconfirmed)

    delete account_deletion_path(locale: :ja), params: { password: PASSWORD }

    assert_response :forbidden
    assert User.exists?(unconfirmed.id)
  end

  test "削除の確認画面に、消えるものとエクスポートへの導線が出る" do
    sign_in_as(@user)

    get account_deletion_path(locale: :ja)

    assert_response :success
    assert_select "main a[href=?]", export_path(locale: :ja)
    assert_select "main li", text: I18n.t("account_deletions.show.removed_items.documents")
  end

  test "パスワードを入力するとアカウントを削除できる" do
    @user.create_candidate_profile!(display_name: "山田 太郎")
    sign_in_as(@user)

    delete account_deletion_path(locale: :ja), params: { password: PASSWORD }

    assert_redirected_to localized_root_path(locale: :ja)
    assert_not User.exists?(@user.id)
  end

  test "誤ったパスワードでは削除されない" do
    # ログイン状態だけで消せると、席を離れた端末からそのまま実行できる。
    sign_in_as(@user)

    delete account_deletion_path(locale: :ja), params: { password: "wrong password here" }

    assert_response :unprocessable_content
    assert User.exists?(@user.id)
  end

  test "パスワードが空でも削除されない" do
    sign_in_as(@user)

    delete account_deletion_path(locale: :ja), params: { password: "" }

    assert_response :unprocessable_content
    assert User.exists?(@user.id)
  end

  test "削除するとログイン状態も終わる" do
    sign_in_as(@user)

    delete account_deletion_path(locale: :ja), params: { password: PASSWORD }
    get account_path(locale: :ja)

    assert_redirected_to new_session_path(locale: :ja)
  end

  test "削除の完了が遷移先の画面に伝わる" do
    sign_in_as(@user)

    delete account_deletion_path(locale: :ja), params: { password: PASSWORD }
    follow_redirect!

    assert_select "main", text: /#{I18n.t("account_deletions.destroy.deleted")}/
  end

  test "組織の唯一の管理者は削除できず、理由の組織名が出る" do
    Organization.create_with_owner!(name: "サンプル株式会社", user: @user)
    sign_in_as(@user)

    get account_deletion_path(locale: :ja)

    assert_select "main li", text: "サンプル株式会社"
    assert_select "main input[type=submit]", count: 0

    delete account_deletion_path(locale: :ja), params: { password: PASSWORD }

    assert_response :unprocessable_content
    assert User.exists?(@user.id)
  end

  test "プロフィールだけを削除するとアカウントは残る" do
    profile = @user.create_candidate_profile!(display_name: "山田 太郎")
    profile.work_experiences.create!(
      organization_name: "株式会社サンプル", position: "人事", started_on: Date.new(2020, 4, 1)
    )
    sign_in_as(@user)

    delete profile_path(locale: :ja)

    assert_redirected_to new_profile_path(locale: :ja)
    assert User.exists?(@user.id)
    assert_equal 0, CandidateProfile.count
    assert_equal 0, WorkExperience.count
  end

  test "プロフィールがない状態で削除しても壊れない" do
    sign_in_as(@user)

    delete profile_path(locale: :ja)

    assert_redirected_to new_profile_path(locale: :ja)
  end

  test "他人のプロフィールを削除する経路がない" do
    # 経路が ID を受け取らないため、対象は常に自分のプロフィールになる。
    other = User.create!(email_address: "other@example.com", password: PASSWORD).tap(&:confirm)
    other.create_candidate_profile!(display_name: "他人の名前")
    @user.create_candidate_profile!(display_name: "山田 太郎")
    sign_in_as(@user)

    delete profile_path(locale: :ja)

    assert CandidateProfile.exists?(other.candidate_profile.id)
  end

  test "削除の画面を日本語と英語で表示する" do
    sign_in_as(@user)

    I18n.available_locales.each do |locale|
      get account_deletion_path(locale: locale)

      assert_response :success
      assert_select "main h1", text: I18n.t("account_deletions.show.title", locale: locale)
    end
  end

  private
    def sign_in_as(user)
      post session_path(locale: :ja), params: { email_address: user.email_address, password: PASSWORD }
    end
end
