require "test_helper"

# 画面ごとの入口条件の契約を検証する。
#
# 検証対象は「誰がどの画面へ入れるか」であり、画面の内容ではない。
class AccessControlTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct horse battery".freeze

  setup do
    @user = User.create!(email_address: "member@example.com", password: PASSWORD)
  end

  test "公開画面は未ログインで表示できる" do
    # 既定で全画面を保護すると、公開画面を足すたびに除外の宣言が要る。
    [
      localized_root_path(locale: :ja),
      new_session_path(locale: :ja),
      new_registration_path(locale: :ja),
      confirmation_path(locale: :ja, token: @user.generate_token_for(:email_confirmation))
    ].each do |path|
      get path

      assert_response :success, "#{path} が未ログインで表示できない"
    end
  end

  test "未ログインでアカウント画面を要求するとログイン画面へ送る" do
    get account_path(locale: :ja)

    assert_redirected_to new_session_path(locale: :ja)
  end

  test "ログインすると要求していた画面へ戻る" do
    # 毎回トップページへ送ると、たどり着きたかった場所を利用者が探し直すことになる。
    @user.confirm
    get account_path(locale: :ja)

    sign_in

    assert_redirected_to account_path(locale: :ja)
  end

  test "戻り先を持たないログインではトップページへ遷移する" do
    @user.confirm

    sign_in

    assert_redirected_to localized_root_path(locale: :ja)
  end

  test "戻り先を一度だけ使う" do
    # 残したままにすると、次のログインでも同じ場所へ送られる。
    @user.confirm
    get account_path(locale: :ja)
    sign_in
    delete session_path(locale: :ja)

    sign_in

    assert_redirected_to localized_root_path(locale: :ja)
  end

  test "戻り先として外部の URL を受け入れない" do
    # 覚えるのは request.fullpath のため、通常の経路では外部の URL は入らない。
    # ここで確かめるのは、セッションの中身が差し替わった場合の防壁である。
    # ログイン直後に外部へ送る踏み台にさせない。
    [ "https://example.com/", "//example.com/", '/\example.com' ].each do |external|
      assert_no_match Authentication::INTERNAL_PATH, external,
        "#{external} を戻り先として受け入れている"
    end

    assert_match Authentication::INTERNAL_PATH, account_path(locale: :ja)
  end

  test "未確認のアカウントではアカウント画面の代わりに確認を促す" do
    sign_in

    get account_path(locale: :ja)

    assert_response :forbidden
    assert_select "main h1", text: I18n.t("confirmations.pending.title")
  end

  test "未確認でもログインとログアウトはできる" do
    # 拒むと、確認メールが届かなかった利用者が再送を依頼する手段まで失う。
    sign_in

    assert_redirected_to localized_root_path(locale: :ja)

    delete session_path(locale: :ja)

    assert_redirected_to localized_root_path(locale: :ja)
  end

  test "確認済みのアカウントではアカウント画面を表示する" do
    @user.confirm
    sign_in

    get account_path(locale: :ja)

    assert_response :success
    assert_select "main", text: /#{Regexp.escape(@user.email_address)}/
  end

  test "制限が日本語と英語の両方で機能する" do
    I18n.available_locales.each do |locale|
      get account_path(locale: locale)

      assert_redirected_to new_session_path(locale: locale)
    end
  end

  private
    def sign_in(locale: :ja)
      post session_path(locale: locale), params: { email_address: @user.email_address, password: PASSWORD }
    end
end
