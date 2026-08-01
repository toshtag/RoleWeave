require "test_helper"

# 組織の中での役割に応じた制限の契約を検証する。
#
# 検証対象は「誰がどの操作をできるか」であり、画面の内容ではない。
class OrganizationAuthorizationTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct horse battery".freeze

  setup do
    @organization = Organization.create!(name: "Example Inc.")
    @owner = confirmed_user("owner@example.com")
    @member = confirmed_user("member@example.com")
    @organization.memberships.create!(user: @owner, role: "owner")
    @member_membership = @organization.memberships.create!(user: @member, role: "member")
  end

  test "所属していればメンバー一覧を見られる" do
    sign_in_as(@member)

    get members_path

    assert_response :success
    assert_select "main li", text: /#{Regexp.escape(@owner.email_address)}/
  end

  test "所属していないアカウントはメンバー一覧を見られない" do
    sign_in_as(confirmed_user("outsider@example.com"))

    get members_path

    assert_response :not_found
  end

  test "管理者は招待を作れる" do
    sign_in_as(@owner)

    get new_organization_invitation_path(locale: :ja, organization_id: @organization)

    assert_response :success
  end

  test "メンバーは招待を作れない" do
    # 入ったばかりのメンバーが誰でも他の人を招待できる状態にしない。
    sign_in_as(@member)

    assert_no_difference -> { Invitation.count } do
      post organization_invitations_path(locale: :ja, organization_id: @organization),
           params: { invitation: { email_address: "invited@example.com", role: "member" } }
    end

    assert_response :not_found
  end

  test "権限がない操作と存在しない組織への操作が同じ応答になる" do
    # 403 と分けると、「その組織が存在すること」だけが分かる状態になる。
    sign_in_as(@member)

    get new_organization_invitation_path(locale: :ja, organization_id: @organization)
    forbidden = response.status

    get new_organization_invitation_path(locale: :ja, organization_id: 0)

    assert_equal forbidden, response.status
  end

  test "管理者は他のメンバーの役割を変更できる" do
    sign_in_as(@owner)

    change_role(@member_membership, "owner")

    assert_predicate @member_membership.reload, :owner?
  end

  test "メンバーは役割を変更できない" do
    sign_in_as(@member)

    change_role(@member_membership, "owner")

    assert_response :not_found
    assert_not_predicate @member_membership.reload, :owner?
  end

  test "自分自身の役割は変更できない" do
    # 誤って自分を降格させると、元へ戻せなくなる。
    #
    # 他に管理者がいる状況で試す。管理者が自分だけだと、
    # 最後の管理者を守る検証の方が先に効き、この契約を確かめられない。
    @member_membership.update_column(:role, "owner")
    sign_in_as(@owner)
    own = @organization.memberships.find_by(user: @owner)

    change_role(own, "member")

    assert_response :unprocessable_content
    assert_predicate own.reload, :owner?
  end

  test "管理者が 2 人いれば片方を降格できる" do
    sign_in_as(@owner)
    @member_membership.update_column(:role, "owner")

    change_role(@member_membership, "member")

    assert_not_predicate @member_membership.reload, :owner?
  end

  test "メンバー一覧を日本語と英語で表示する" do
    sign_in_as(@owner)

    I18n.available_locales.each do |locale|
      get organization_memberships_path(locale: locale, organization_id: @organization)

      assert_response :success
      assert_select "main h1",
        text: I18n.t("memberships.index.title", organization: @organization.name, locale: locale)
    end
  end

  private
    def confirmed_user(email_address)
      User.create!(email_address: email_address, password: PASSWORD).tap(&:confirm)
    end

    def sign_in_as(user)
      post session_path(locale: :ja), params: { email_address: user.email_address, password: PASSWORD }
    end

    def members_path
      organization_memberships_path(locale: :ja, organization_id: @organization)
    end

    def change_role(membership, role)
      patch organization_membership_path(locale: :ja, organization_id: @organization, id: membership),
            params: { membership: { role: role } }
    end
end
