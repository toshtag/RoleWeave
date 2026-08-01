require "test_helper"

# 招待の契約を検証する。
#
# 検証対象は、宛先の扱いと受諾したときの結果である。
# 受諾の経路と条件は integration のテストが持つ。
class InvitationTest < ActiveSupport::TestCase
  PASSWORD = "correct horse battery".freeze

  setup do
    @organization = Organization.create!(name: "Example Inc.")
    @inviter = User.create!(email_address: "owner@example.com", password: PASSWORD)
    @organization.memberships.create!(user: @inviter, role: "owner")
  end

  test "宛先と役割を持つ招待を作れる" do
    assert_predicate invitation, :persisted?
  end

  test "宛先を正規化する" do
    # 規則がずれると、同じ相手への招待が表記ごとに分かれる。
    assert_equal "invited@example.com", invitation(email_address: " Invited@Example.COM ").email_address
  end

  test "形式が不正な宛先を拒否する" do
    assert_not @organization.invitations.new(email_address: "invited", role: "member").valid?
  end

  test "決められた役割だけを受け付ける" do
    Membership::ROLES.each do |role|
      assert_predicate @organization.invitations.new(email_address: "invited@example.com", role: role), :valid?
    end

    assert_not @organization.invitations.new(email_address: "invited@example.com", role: "unknown").valid?
  end

  test "同じ宛先の未受諾の招待を 2 件作れない" do
    invitation

    assert_not @organization.invitations.new(email_address: "invited@example.com", role: "member").valid?
  end

  test "受諾済みなら同じ宛先へもう一度招待できる" do
    # 同じ人が抜けた後に、招待し直せる必要がある。
    invitation.update!(accepted_at: Time.current)

    assert_predicate @organization.invitations.new(email_address: "invited@example.com", role: "member"), :valid?
  end

  test "別の組織へは同じ宛先で招待できる" do
    invitation
    other = Organization.create!(name: "Another Inc.")

    assert_predicate other.invitations.new(email_address: "invited@example.com", role: "member"), :valid?
  end

  test "受諾すると所属が作られる" do
    record = invitation

    assert_difference -> { Membership.count }, 1 do
      record.accept!(invited_user)
    end

    assert_predicate record.reload, :accepted?
    assert_equal "member", @organization.memberships.find_by(user: invited_user).role
  end

  test "すでに所属があるときは所属を増やさない" do
    # 「受諾できなかった」と伝えると、すでに入れている利用者を混乱させる。
    record = invitation
    @organization.memberships.create!(user: invited_user, role: "owner")

    assert_no_difference -> { Membership.count } do
      record.accept!(invited_user)
    end

    assert_predicate record.reload, :accepted?
  end

  test "受諾すると発行済みのリンクが使えなくなる" do
    record = invitation
    token = record.generate_token_for(:acceptance)

    record.accept!(invited_user)

    assert_nil Invitation.find_by_token_for(:acceptance, token)
  end

  test "組織を削除すると招待も消える" do
    invitation

    assert_difference -> { Invitation.count }, -1 do
      @organization.destroy
    end
  end

  test "招待した人を削除しても招待は残る" do
    record = invitation

    assert_no_difference -> { Invitation.count } do
      @inviter.destroy
    end

    assert_nil record.reload.invited_by_id
  end

  private
    def invitation(email_address: "invited@example.com", role: "member")
      @invitation ||= @organization.invitations.create!(
        email_address: email_address,
        role: role,
        invited_by: @inviter
      )
    end

    def invited_user
      @invited_user ||= User.create!(email_address: "invited@example.com", password: PASSWORD)
    end
end
