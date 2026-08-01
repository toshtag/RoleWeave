require "test_helper"

# 認証の記録の契約を検証する。
#
# 検証対象は記録できる値と、アカウントを削除したときの扱いである。
# どの操作でどの記録が残るかは integration のテストが持つ。
class AuthenticationEventTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email_address: "member@example.com", password: "correct horse battery")
  end

  test "決められた種類だけを受け付ける" do
    # 自由な文字列を許すと、集計のたびに表記のゆれを吸収することになる。
    AuthenticationEvent::KINDS.each do |kind|
      assert_predicate AuthenticationEvent.new(kind: kind, email_address: @user.email_address), :valid?
    end

    assert_not AuthenticationEvent.new(kind: "unknown", email_address: @user.email_address).valid?
  end

  test "メールアドレスのない記録を作れない" do
    assert_not AuthenticationEvent.new(kind: "sign_in_failed").valid?
  end

  test "メールアドレスを正規化して記録する" do
    # User と同じ規則にそろえないと、同じ相手の記録が表記ごとに分かれる。
    event = AuthenticationEvent.create!(kind: "sign_in_failed", email_address: "  Member@Example.COM ")

    assert_equal "member@example.com", event.email_address
  end

  test "アカウントに結び付かない記録を作れる" do
    # 存在しないメールアドレスへの試行は、どのアカウントのものでもない。
    event = AuthenticationEvent.create!(kind: "sign_in_failed", email_address: "unknown@example.com")

    assert_nil event.user
  end

  test "アカウントを削除しても記録は残る" do
    # いつ何が起きたかまで消すと、削除の前後の調査ができなくなる。
    event = AuthenticationEvent.record(kind: :sign_in_succeeded, email_address: @user.email_address, user: @user)

    assert_no_difference -> { AuthenticationEvent.count } do
      @user.destroy
    end

    assert_nil event.reload.user_id
  end

  test "リクエストを渡さなくても記録できる" do
    event = AuthenticationEvent.record(kind: :sign_in_failed, email_address: "unknown@example.com")

    assert_nil event.ip_address
    assert_nil event.user_agent
  end
end
