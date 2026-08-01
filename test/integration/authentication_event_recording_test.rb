require "test_helper"

# どの操作でどの記録が残るかを検証する。
#
# 記録は後から足せない。過去の出来事は復元できないため、
# 経路ごとに 1 行ずつ残ることをここで固定する。
class AuthenticationEventRecordingTest < ActionDispatch::IntegrationTest
  EMAIL_ADDRESS = "member@example.com".freeze
  PASSWORD = "correct horse battery".freeze
  USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " \
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36".freeze

  setup do
    @user = User.create!(email_address: EMAIL_ADDRESS, password: PASSWORD)
  end

  test "ログインの成功を記録する" do
    assert_difference -> { AuthenticationEvent.count }, 1 do
      sign_in
    end

    event = AuthenticationEvent.last

    assert_equal "sign_in_succeeded", event.kind
    assert_equal @user, event.user
    assert_equal EMAIL_ADDRESS, event.email_address
  end

  test "ログインの失敗を記録する" do
    # 成功だけを残すと、繰り返された試行が見えない。
    assert_difference -> { AuthenticationEvent.count }, 1 do
      sign_in(password: "#{PASSWORD}x")
    end

    assert_equal "sign_in_failed", AuthenticationEvent.last.kind
  end

  test "存在しないメールアドレスへの失敗も記録する" do
    sign_in(email_address: "unknown@example.com")

    event = AuthenticationEvent.last

    assert_equal "sign_in_failed", event.kind
    assert_nil event.user
    assert_equal "unknown@example.com", event.email_address
  end

  test "入力されたメールアドレスを正規化して記録する" do
    sign_in(email_address: " Member@Example.COM ")

    assert_equal EMAIL_ADDRESS, AuthenticationEvent.last.email_address
  end

  test "ログアウトを記録する" do
    sign_in

    assert_difference -> { AuthenticationEvent.count }, 1 do
      delete session_path(locale: :ja)
    end

    event = AuthenticationEvent.last

    assert_equal "sign_out", event.kind
    assert_equal @user, event.user
  end

  test "パスワード再設定の完了を記録する" do
    assert_difference -> { AuthenticationEvent.count }, 1 do
      patch update_password_reset_path(locale: :ja, token: @user.password_reset_token), params: {
        user: { password: "another long secret", password_confirmation: "another long secret" }
      }
    end

    event = AuthenticationEvent.last

    assert_equal "password_reset_completed", event.kind
    assert_equal @user, event.user
  end

  test "送信元と User-Agent を記録する" do
    sign_in(headers: { "User-Agent" => USER_AGENT })

    event = AuthenticationEvent.last

    assert_equal USER_AGENT, event.user_agent
    assert event.ip_address.present?, "送信元が記録されていない"
  end

  test "パスワードと token を記録しない" do
    sign_in(password: "#{PASSWORD}x")

    assert_not_includes AuthenticationEvent.last.attributes.values.map(&:to_s).join(" "), PASSWORD
  end

  private
    def sign_in(locale: :ja, email_address: EMAIL_ADDRESS, password: PASSWORD, headers: {})
      post session_path(locale: locale),
           params: { email_address: email_address, password: password },
           headers: headers
    end
end
