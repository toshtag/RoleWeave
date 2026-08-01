require "test_helper"

# メールアドレスの確認の契約を検証する。
#
# 検証対象は、確認リンクをたどったときに何が起こるかである。
# メールの内容そのものは user_mailer_test が持つ。
class EmailConfirmationTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "member@example.com", password: "correct horse battery")
  end

  test "アカウント作成で確認メールを 1 通送る" do
    assert_enqueued_emails 1 do
      post registration_path(locale: :ja), params: {
        user: {
          email_address: "new@example.com",
          password: "correct horse battery",
          password_confirmation: "correct horse battery"
        }
      }
    end
  end

  test "作成した直後は未確認である" do
    assert_not_predicate @user, :confirmed?
    assert_nil @user.confirmed_at
  end

  test "正しいリンクで確認を記録する" do
    get confirmation_path(locale: :ja, token: token)

    assert_response :success
    assert_predicate @user.reload, :confirmed?
  end

  test "確認の結果を日本語と英語で表示する" do
    I18n.available_locales.each do |locale|
      get confirmation_path(locale: locale, token: token)

      assert_response :success
      assert_select "html[lang=?]", locale.to_s
      assert_select "main h1", text: I18n.t("confirmations.show.confirmed.title", locale: locale)
    end
  end

  test "すでに確認済みでも失敗にしない" do
    # リンクを 2 回たどるのは普通の操作であり、そこで無効と出すと確認できていないように見える。
    @user.confirm
    confirmed_at = @user.reload.confirmed_at

    get confirmation_path(locale: :ja, token: token)

    assert_response :success
    assert_equal confirmed_at.to_i, @user.reload.confirmed_at.to_i
  end

  test "壊れた token で確認できない" do
    get confirmation_path(locale: :ja, token: "broken")

    assert_response :unprocessable_content
    assert_not_predicate @user.reload, :confirmed?
    assert_select "main h1", text: I18n.t("confirmations.show.invalid.title")
  end

  test "期限を過ぎた token で確認できない" do
    expired = travel_to(User::EMAIL_CONFIRMATION_EXPIRES_IN.ago - 1.minute) { token }

    get confirmation_path(locale: :ja, token: expired)

    assert_response :unprocessable_content
    assert_not_predicate @user.reload, :confirmed?
  end

  test "別のアカウントの token で確認できない" do
    other = User.create!(email_address: "other@example.com", password: "correct horse battery")

    get confirmation_path(locale: :ja, token: token(other))

    assert_not_predicate @user.reload, :confirmed?
    assert_predicate other.reload, :confirmed?
  end

  test "メールアドレスを変えると変更前の token を使えない" do
    # 確認したい宛先が変わった後に古いリンクが通ると、
    # 実在を確かめていないアドレスが確認済みになる。
    old_token = token
    @user.update!(email_address: "changed@example.com")

    get confirmation_path(locale: :ja, token: old_token)

    assert_response :unprocessable_content
    assert_not_predicate @user.reload, :confirmed?
  end

  test "確認の失敗理由を画面で区別しない" do
    # 区別すると、token を試すときの手がかりになる。
    get confirmation_path(locale: :ja, token: "broken")
    broken = css_select("main h1").first.text

    expired = travel_to(User::EMAIL_CONFIRMATION_EXPIRES_IN.ago - 1.minute) { token }
    get confirmation_path(locale: :ja, token: expired)

    assert_equal broken, css_select("main h1").first.text
  end

  private
    def token(user = @user)
      user.generate_token_for(:email_confirmation)
    end
end
