require "test_helper"

# 所属の契約を検証する。
class MembershipTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(name: "Example Inc.")
    @user = User.create!(email_address: "member@example.com", password: "correct horse battery")
  end

  test "決められた役割だけを受け付ける" do
    Membership::ROLES.each do |role|
      assert_predicate Membership.new(organization: @organization, user: @user, role: role), :valid?
    end

    assert_not Membership.new(organization: @organization, user: @user, role: "unknown").valid?
  end

  test "同じアカウントを同じ組織へ 2 度所属させない" do
    @organization.memberships.create!(user: @user, role: "owner")

    assert_not Membership.new(organization: @organization, user: @user, role: "member").valid?
  end

  test "検証を迂回した重複をデータベースが拒否する" do
    # 検証だけでは、同時に届いた 2 つの追加の間で重複を防げない。
    @organization.memberships.create!(user: @user, role: "owner")

    assert_raises(ActiveRecord::RecordNotUnique) do
      Membership.insert_all!([ {
        organization_id: @organization.id,
        user_id: @user.id,
        role: "member",
        created_at: Time.current,
        updated_at: Time.current
      } ])
    end
  end

  test "1 人のアカウントが複数の組織へ所属できる" do
    # 代理店や兼務によって、複数の組織に関わる担当者がいる。
    other = Organization.create!(name: "Another Inc.")
    @organization.memberships.create!(user: @user, role: "owner")
    other.memberships.create!(user: @user, role: "member")

    assert_equal 2, @user.organizations.count
  end

  test "アカウントを削除すると所属も消える" do
    @organization.memberships.create!(user: @user, role: "owner")

    assert_difference -> { Membership.count }, -1 do
      @user.destroy
    end
  end

  test "組織のないアカウントのない所属を作れない" do
    assert_not Membership.new(role: "owner").valid?
  end
end
