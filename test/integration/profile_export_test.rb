require "test_helper"

# 自分のデータの持ち出しの経路の契約を検証する。
#
# 検証対象は、誰が取れるかと、どう返すかである。
class ProfileExportDownloadTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct horse battery".freeze

  setup do
    @user = User.create!(email_address: "member@example.com", password: PASSWORD).tap(&:confirm)
  end

  test "未ログインではエクスポートできない" do
    get export_path(locale: :ja)

    assert_redirected_to new_session_path(locale: :ja)
  end

  test "メールアドレスが未確認ではエクスポートできない" do
    unconfirmed = User.create!(email_address: "unconfirmed@example.com", password: PASSWORD)
    sign_in_as(unconfirmed)

    get export_path(locale: :ja)

    assert_response :forbidden
  end

  test "本人が自分のデータを JSON でダウンロードできる" do
    @user.create_candidate_profile!(display_name: "山田 太郎")
    sign_in_as(@user)

    get export_path(locale: :ja)

    assert_response :success
    assert_equal "application/json", response.media_type
    assert_match(/\Aattachment;/, response.headers["Content-Disposition"])
    assert_equal "山田 太郎", JSON.parse(response.body)["candidate_profile"]["display_name"]
  end

  test "エクスポートには自分のデータだけが出る" do
    # 経路が ID を受け取らないため、他人のデータを指す方法がない。
    # 「最初のアカウント」を返す実装になっていないことを、
    # 後から登録した側でログインして確かめる。
    @user.create_candidate_profile!(display_name: "先に登録した人")
    later = User.create!(email_address: "later@example.com", password: PASSWORD).tap(&:confirm)
    later.create_candidate_profile!(display_name: "後から登録した人")
    sign_in_as(later)

    get export_path(locale: :ja)

    assert_match(/後から登録した人/, response.body)
    assert_no_match(/先に登録した人/, response.body)
    assert_no_match(/member@example.com/, response.body)
  end

  test "プロフィールがなくてもダウンロードできる" do
    sign_in_as(@user)

    get export_path(locale: :ja)

    assert_response :success
    assert_nil JSON.parse(response.body)["candidate_profile"]
  end

  test "アカウントの画面から導線がある" do
    sign_in_as(@user)

    get account_path(locale: :ja)

    assert_select "main a[href=?]", export_path(locale: :ja)
  end

  private
    def sign_in_as(user)
      post session_path(locale: :ja), params: { email_address: user.email_address, password: PASSWORD }
    end
end
