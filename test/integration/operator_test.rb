require "test_helper"

# 運営者権限の契約を検証する。
#
# 検証対象は、運営者だけが入れる経路と、そこでできることである。
class OperatorTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct horse battery".freeze

  setup do
    @operator = confirmed_user("operator@example.com")
    @operator.update!(operator: true)

    @member = confirmed_user("member@example.com")
    @organization = Organization.create_with_owner!(name: "Example Inc.", user: @member)
  end

  test "運営者はすべての組織の一覧を見られる" do
    other = Organization.create!(name: "Another Inc.")
    sign_in_as(@operator)

    get operator_organizations_path(locale: :ja)

    assert_response :success
    assert_select "main li", text: /#{Regexp.escape(@organization.name)}/
    assert_select "main li", text: /#{Regexp.escape(other.name)}/
  end

  test "運営者でないアカウントは運営者の経路へ入れない" do
    # 403 と分けると、運営者の経路が存在することだけが分かる。
    sign_in_as(@member)

    get operator_organizations_path(locale: :ja)

    assert_response :not_found
  end

  test "未ログインでは運営者の経路へ入れない" do
    get operator_organizations_path(locale: :ja)

    assert_redirected_to new_session_path(locale: :ja)
  end

  test "運営者は所属していない組織の内容を見られる" do
    sign_in_as(@operator)

    get operator_organization_path(locale: :ja, id: @organization)

    assert_response :success
    assert_select "main li", text: /#{Regexp.escape(@member.email_address)}/
  end

  test "運営者はメンバーへ管理者の役割を与えられる" do
    other = confirmed_user("other@example.com")
    membership = @organization.memberships.create!(user: other, role: "member")
    sign_in_as(@operator)

    grant_owner(membership)

    assert_predicate membership.reload, :owner?
  end

  test "運営者による付与が履歴へ残り主体が運営者になる" do
    other = confirmed_user("other@example.com")
    membership = @organization.memberships.create!(user: other, role: "member")
    sign_in_as(@operator)

    assert_difference -> { MembershipEvent.count }, 1 do
      grant_owner(membership)
    end

    event = MembershipEvent.last

    assert_equal "role_changed", event.kind
    assert_equal @operator, event.changed_by
  end

  test "管理者が 0 人の組織でも管理者を立てられる" do
    # ADR 0013 で、この状態からの復旧は運営者権限を待つと記録していた。
    @organization.memberships.update_all(role: "member")
    membership = @organization.memberships.first
    sign_in_as(@operator)

    grant_owner(membership)

    assert_predicate membership.reload, :owner?
  end

  test "運営者でないアカウントは役割を与えられない" do
    other = confirmed_user("other@example.com")
    membership = @organization.memberships.create!(user: other, role: "member")
    sign_in_as(@member)

    grant_owner(membership)

    assert_response :not_found
    assert_not_predicate membership.reload, :owner?
  end

  test "運営者の経路を日本語と英語で表示する" do
    sign_in_as(@operator)

    I18n.available_locales.each do |locale|
      get operator_organizations_path(locale: locale)

      assert_response :success
      assert_select "main h1", text: I18n.t("operator.organizations.index.title", locale: locale)
    end
  end

  private
    def confirmed_user(email_address)
      User.create!(email_address: email_address, password: PASSWORD).tap(&:confirm)
    end

    def sign_in_as(user)
      post session_path(locale: :ja), params: { email_address: user.email_address, password: PASSWORD }
    end

    def grant_owner(membership)
      patch operator_organization_membership_path(
        locale: :ja,
        organization_id: membership.organization_id,
        id: membership
      )
    end
end
