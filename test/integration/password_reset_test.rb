require "test_helper"

# パスワード再設定の契約を検証する。
#
# 検証対象は、依頼から再設定までの経路と、再設定が既存の状態へ与える影響である。
class PasswordResetTest < ActionDispatch::IntegrationTest
  EMAIL_ADDRESS = "member@example.com".freeze
  OLD_PASSWORD = "correct horse battery".freeze
  NEW_PASSWORD = "another long secret".freeze

  setup do
    @user = User.create!(email_address: EMAIL_ADDRESS, password: OLD_PASSWORD)
  end

  test "依頼画面を日本語と英語で表示する" do
    I18n.available_locales.each do |locale|
      get new_password_reset_path(locale: locale)

      assert_response :success
      assert_select "main h1", text: I18n.t("password_resets.new.title", locale: locale)
    end
  end

  test "登録済みのメールアドレスへ再設定メールを 1 通送る" do
    assert_enqueued_emails 1 do
      request_reset
    end
  end

  test "登録のないメールアドレスではメールを送らない" do
    assert_no_enqueued_emails do
      request_reset(email_address: "unknown@example.com")
    end
  end

  test "登録の有無で応答を変えない" do
    # 区別すると、この画面が登録済みのメールアドレスを調べる道具になる。
    request_reset
    registered = response.body

    request_reset(email_address: "unknown@example.com")

    assert_equal registered, response.body
  end

  test "正しい token で新しいパスワードを設定できる" do
    get edit_password_reset_path(locale: :ja, token: token)

    assert_response :success

    submit_new_password

    assert_redirected_to new_session_path(locale: :ja)
    assert @user.reload.authenticate(NEW_PASSWORD), "新しいパスワードで認証できない"
  end

  test "再設定すると古いパスワードで認証できない" do
    submit_new_password

    assert_not @user.reload.authenticate(OLD_PASSWORD)
  end

  test "再設定後は自動でログインしない" do
    # 新しいパスワードで入れることを、利用者自身がその場で確かめられる状態にする。
    submit_new_password
    follow_redirect!

    assert_select "header .site-header__account-name", count: 0
  end

  test "一度使った token を再利用できない" do
    used = token
    submit_new_password(token: used)

    get edit_password_reset_path(locale: :ja, token: used)

    assert_response :unprocessable_content
  end

  test "期限を過ぎた token では再設定できない" do
    expired = travel_to(User::PASSWORD_RESET_EXPIRES_IN.ago - 1.minute) { token }

    get edit_password_reset_path(locale: :ja, token: expired)

    assert_response :unprocessable_content
  end

  test "壊れた token で例外にならない" do
    get edit_password_reset_path(locale: :ja, token: "broken")

    assert_response :unprocessable_content
    assert_select "main h1", text: I18n.t("password_resets.invalid.title")
  end

  test "短すぎるパスワードでは再設定できない" do
    submit_new_password(password: "short")

    assert_response :unprocessable_content
    assert @user.reload.authenticate(OLD_PASSWORD), "古いパスワードが失われている"
  end

  test "確認用の入力が一致しないと再設定できない" do
    submit_new_password(password_confirmation: "#{NEW_PASSWORD}x")

    assert_response :unprocessable_content
    assert @user.reload.authenticate(OLD_PASSWORD)
  end

  test "再設定するとそのアカウントのセッションをすべて破棄する" do
    # 変更の理由が乗っ取りだった場合、残したままでは相手が居座り続ける。
    2.times { @user.sessions.create! }

    assert_difference -> { @user.sessions.count }, -2 do
      submit_new_password
    end
  end

  test "他のアカウントのセッションを破棄しない" do
    other = User.create!(email_address: "other@example.com", password: OLD_PASSWORD)
    other.sessions.create!

    assert_no_difference -> { other.sessions.count } do
      submit_new_password
    end
  end

  test "ログイン画面から再設定へたどれる" do
    get new_session_path(locale: :ja)

    assert_select "main a[href=?]", new_password_reset_path(locale: :ja)
  end

  private
    def token
      @user.reload.generate_token_for(:password_reset)
    end

    def request_reset(locale: :ja, email_address: EMAIL_ADDRESS)
      post password_reset_path(locale: locale), params: { email_address: email_address }
    end

    def submit_new_password(token: nil, password: NEW_PASSWORD, password_confirmation: nil)
      patch update_password_reset_path(locale: :ja, token: token || self.token), params: {
        user: {
          password: password,
          password_confirmation: password_confirmation || password
        }
      }
    end
end
