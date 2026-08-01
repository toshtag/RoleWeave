require "test_helper"

# 組織の契約を検証する。
class OrganizationTest < ActiveSupport::TestCase
  test "名前を持つ組織を作成できる" do
    assert_predicate Organization.create(name: "Example Inc."), :persisted?
  end

  test "名前の前後の空白を取り除く" do
    # 表示名の違いが空白だけ、という状態を作らない。
    assert_equal "Example Inc.", Organization.new(name: "  Example Inc. ").name
  end

  test "名前のない組織を拒否する" do
    assert_not Organization.new(name: nil).valid?
    assert_not Organization.new(name: "   ").valid?
  end

  test "上限を超える名前を拒否する" do
    assert_not Organization.new(name: "a" * (Organization::NAME_MAX_LENGTH + 1)).valid?
  end

  test "同じ名前の組織を作成できる" do
    # 同名の組織は実在する。名前で一意にすると、後から来た組織が登録できない。
    Organization.create!(name: "Example Inc.")

    assert_predicate Organization.new(name: "Example Inc."), :valid?
  end

  test "組織を削除すると所属も消える" do
    organization = Organization.create!(name: "Example Inc.")
    organization.memberships.create!(user: user, role: "owner")

    assert_difference -> { Membership.count }, -1 do
      organization.destroy
    end
  end

  test "組織と最初の所属をまとめて作れる" do
    owner = user

    organization = Organization.create_with_owner!(name: "Example Inc.", user: owner)

    assert_equal owner, organization.memberships.sole.user
    assert_predicate organization.memberships.sole, :owner?
  end

  test "所属の作成に失敗したら組織も残らない" do
    # 片方だけが残ると、誰も入れない組織ができる。
    assert_no_difference -> { Organization.count } do
      assert_raises(ActiveRecord::RecordInvalid) do
        Organization.create_with_owner!(name: "Example Inc.", user: user, role: "unknown")
      end
    end
  end

  private
    def user(email_address = "member@example.com")
      User.create!(email_address: email_address, password: "correct horse battery")
    end
end
