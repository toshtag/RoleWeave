require "test_helper"

# 所属の変更の記録の契約を検証する。
#
# 検証対象は、記録できる値と削除したときの扱いである。
# どの操作でどの記録が残るかは integration のテストが持つ。
class MembershipEventTest < ActiveSupport::TestCase
  PASSWORD = "correct horse battery".freeze

  setup do
    @organization = Organization.create!(name: "Example Inc.")
    @user = User.create!(email_address: "member@example.com", password: PASSWORD)
  end

  test "決められた種類だけを受け付ける" do
    MembershipEvent::KINDS.each do |kind|
      assert_predicate build(kind: kind), :valid?
    end

    assert_not build(kind: "unknown").valid?
  end

  test "決められた役割だけを受け付ける" do
    assert_not build(to_role: "unknown").valid?
    assert_not build(from_role: "unknown", kind: "role_changed").valid?
  end

  test "所属を作ると記録が残る" do
    assert_difference -> { MembershipEvent.count }, 1 do
      @organization.memberships.create!(user: @user, role: "member", changed_by: @user)
    end

    event = MembershipEvent.last

    assert_equal "joined", event.kind
    assert_equal "member", event.to_role
    assert_nil event.from_role
    assert_equal @user, event.changed_by
  end

  test "役割を変えると変更前と変更後が残る" do
    membership = @organization.memberships.create!(user: @user, role: "owner")
    other = User.create!(email_address: "other@example.com", password: PASSWORD)
    second = @organization.memberships.create!(user: other, role: "owner")

    assert_difference -> { MembershipEvent.count }, 1 do
      second.update!(role: "member")
    end

    event = MembershipEvent.last

    assert_equal "role_changed", event.kind
    assert_equal "owner", event.from_role
    assert_equal "member", event.to_role
    assert_equal other, event.user
    assert_predicate membership, :owner?
  end

  test "役割以外の変更では記録が増えない" do
    membership = @organization.memberships.create!(user: @user, role: "member")

    assert_no_difference -> { MembershipEvent.count } do
      membership.touch
    end
  end

  test "組織を削除しても記録は残る" do
    # 「いつ何が起きたか」まで消すと、削除の前後の調査ができなくなる。
    @organization.memberships.create!(user: @user, role: "member")

    assert_no_difference -> { MembershipEvent.count } do
      @organization.destroy
    end

    assert_nil MembershipEvent.last.organization_id
  end

  test "アカウントを削除しても記録は残る" do
    @organization.memberships.create!(user: @user, role: "member")

    assert_no_difference -> { MembershipEvent.count } do
      @user.destroy
    end

    assert_nil MembershipEvent.last.user_id
  end

  test "記録した内容を後から変えられない" do
    # 付け替えられると、履歴が別の組織の話になる。
    @organization.memberships.create!(user: @user, role: "member")
    event = MembershipEvent.last

    assert_raises(ActiveRecord::ReadonlyAttributeError) do
      event.update!(to_role: "owner")
    end
  end

  private
    def build(kind: "joined", to_role: "member", from_role: nil)
      MembershipEvent.new(
        organization: @organization,
        user: @user,
        kind: kind,
        to_role: to_role,
        from_role: from_role
      )
    end
end
