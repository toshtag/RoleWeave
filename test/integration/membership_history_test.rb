require "test_helper"

# 権限変更の履歴が、経路を問わず残ることを検証する。
#
# 記録は後から足せない。過去の出来事は復元できないため、
# 所属を作る・変える経路ごとに残ることをここで固定する。
class MembershipHistoryTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct horse battery".freeze

  setup do
    @owner = confirmed_user("owner@example.com")
    @member = confirmed_user("member@example.com")
  end

  test "組織の作成で作成者の参加が記録される" do
    sign_in_as(@owner)

    assert_difference -> { MembershipEvent.count }, 1 do
      post organizations_path(locale: :ja), params: { organization: { name: "Example Inc." } }
    end

    event = MembershipEvent.last

    assert_equal "joined", event.kind
    assert_equal "owner", event.to_role
    assert_equal @owner, event.changed_by
  end

  test "招待の受諾で参加が記録され主体は本人になる" do
    organization = create_organization
    invitation = organization.invitations.create!(
      email_address: @member.email_address,
      role: "member",
      invited_by: @owner
    )
    sign_in_as(@member)

    assert_difference -> { MembershipEvent.count }, 1 do
      get invitation_path(locale: :ja, token: invitation.generate_token_for(:acceptance))
    end

    event = MembershipEvent.last

    assert_equal "joined", event.kind
    assert_equal @member, event.user
    assert_equal @member, event.changed_by
  end

  test "役割の変更で変更前と変更後と主体が記録される" do
    organization = create_organization
    membership = organization.memberships.create!(user: @member, role: "member")
    sign_in_as(@owner)

    assert_difference -> { MembershipEvent.count }, 1 do
      patch organization_membership_path(locale: :ja, organization_id: organization, id: membership),
            params: { membership: { role: "owner" } }
    end

    event = MembershipEvent.last

    assert_equal "role_changed", event.kind
    assert_equal "member", event.from_role
    assert_equal "owner", event.to_role
    assert_equal @owner, event.changed_by
  end

  test "管理者は履歴を見られる" do
    organization = create_organization
    sign_in_as(@owner)

    get organization_memberships_path(locale: :ja, organization_id: organization)

    assert_response :success
    assert_select "main h2", text: I18n.t("memberships.index.history")
  end

  test "メンバーは履歴を見られない" do
    # 誰がいつ役割を変えたかは、組織の運営に属する情報である。
    organization = create_organization
    organization.memberships.create!(user: @member, role: "member")
    sign_in_as(@member)

    get organization_memberships_path(locale: :ja, organization_id: organization)

    assert_response :success
    assert_select "main h2", text: I18n.t("memberships.index.history"), count: 0
  end

  test "履歴を日本語と英語で表示する" do
    organization = create_organization
    sign_in_as(@owner)

    I18n.available_locales.each do |locale|
      get organization_memberships_path(locale: locale, organization_id: organization)

      assert_response :success
      assert_select "main h2", text: I18n.t("memberships.index.history", locale: locale)
    end
  end

  private
    def confirmed_user(email_address)
      User.create!(email_address: email_address, password: PASSWORD).tap(&:confirm)
    end

    def sign_in_as(user)
      post session_path(locale: :ja), params: { email_address: user.email_address, password: PASSWORD }
    end

    def create_organization
      Organization.create_with_owner!(name: "Example Inc.", user: @owner)
    end
end
