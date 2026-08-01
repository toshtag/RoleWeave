require "test_helper"

# 他組織のデータへ到達できないことを検証する。
#
# 検証対象は、ID を直接指定したときの応答である。
# 画面に出るかどうかではなく、経路として到達できないことを確かめる。
class OrganizationIsolationTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct horse battery".freeze

  setup do
    @organization = Organization.create!(name: "Example Inc.")
    @owner = confirmed_user("owner@example.com")
    @organization.memberships.create!(user: @owner, role: "owner")

    @other_organization = Organization.create!(name: "Another Inc.")
    @other_owner = confirmed_user("other-owner@example.com")
    @other_membership = @other_organization.memberships.create!(user: @other_owner, role: "owner")

    sign_in_as(@owner)
  end

  test "他組織のメンバー一覧を ID の直接指定で見られない" do
    get organization_memberships_path(locale: :ja, organization_id: @other_organization)

    assert_response :not_found
  end

  test "他組織のメンバーの役割を ID の直接指定で変更できない" do
    patch organization_membership_path(
      locale: :ja,
      organization_id: @other_organization,
      id: @other_membership
    ), params: { membership: { role: "member" } }

    assert_response :not_found
    assert_predicate @other_membership.reload, :owner?
  end

  test "自組織の経路から他組織のメンバーを変更できない" do
    # 組織だけを自分のものにして、対象のレコードを他組織のものにする。
    patch organization_membership_path(
      locale: :ja,
      organization_id: @organization,
      id: @other_membership
    ), params: { membership: { role: "member" } }

    assert_response :not_found
    assert_predicate @other_membership.reload, :owner?
  end

  test "他組織へ招待を作れない" do
    assert_no_difference -> { Invitation.count } do
      post organization_invitations_path(locale: :ja, organization_id: @other_organization),
           params: { invitation: { email_address: "invited@example.com", role: "member" } }
    end

    assert_response :not_found
  end

  test "自組織のメンバー一覧に他組織のメンバーが出ない" do
    get organization_memberships_path(locale: :ja, organization_id: @organization)

    assert_response :success
    assert_select "main", text: /#{Regexp.escape(@owner.email_address)}/
    assert_select "main li", text: /#{Regexp.escape(@other_owner.email_address)}/, count: 0
  end

  test "所属を他組織へ付け替えられない" do
    # 変えられると、自分の組織のレコードを他組織へ付け替えられる。
    membership = @organization.memberships.find_by(user: @owner)

    # 黙って無視するのではなく、書き換えようとした時点で失敗する。
    assert_raises(ActiveRecord::ReadonlyAttributeError) do
      membership.update!(organization_id: @other_organization.id)
    end

    assert_equal @organization.id, membership.reload.organization_id
  end

  test "招待を他組織へ付け替えられない" do
    invitation = @organization.invitations.create!(
      email_address: "invited@example.com",
      role: "member",
      invited_by: @owner
    )

    assert_raises(ActiveRecord::ReadonlyAttributeError) do
      invitation.update!(organization_id: @other_organization.id)
    end

    assert_equal @organization.id, invitation.reload.organization_id
  end

  private
    def confirmed_user(email_address)
      User.create!(email_address: email_address, password: PASSWORD).tap(&:confirm)
    end

    def sign_in_as(user)
      post session_path(locale: :ja), params: { email_address: user.email_address, password: PASSWORD }
    end
end
