require "test_helper"

# 招待の作成と受諾の契約を検証する。
#
# 検証対象は、誰が招待でき、誰が受諾できるかである。
# 招待そのものの規則は invitation_test が持つ。
class OrganizationInvitationTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct horse battery".freeze
  INVITED = "invited@example.com".freeze

  setup do
    @organization = Organization.create!(name: "Example Inc.")
    @owner = confirmed_user("owner@example.com")
    @organization.memberships.create!(user: @owner, role: "owner")
  end

  test "所属するアカウントが招待を作れる" do
    sign_in_as(@owner)

    assert_difference -> { Invitation.count }, 1 do
      invite
    end

    assert_redirected_to organizations_path(locale: :ja)
  end

  test "招待の作成でメールを 1 通送る" do
    sign_in_as(@owner)

    assert_enqueued_emails 1 do
      invite
    end
  end

  test "所属しないアカウントは招待を作れない" do
    # Organization.find だと、所属していない組織の存在を確かめられる。
    outsider = confirmed_user("outsider@example.com")
    sign_in_as(outsider)

    assert_no_difference -> { Invitation.count } do
      invite
    end

    # 存在しない組織と同じ応答にする。所属していない組織の存在を確かめられない。
    assert_response :not_found
  end

  test "未ログインでは招待を作れない" do
    assert_no_difference -> { Invitation.count } do
      invite
    end

    assert_redirected_to new_session_path(locale: :ja)
  end

  test "形式が不正な宛先では招待を作れない" do
    sign_in_as(@owner)

    assert_no_difference -> { Invitation.count } do
      invite(email_address: "invited")
    end

    assert_response :unprocessable_content
  end

  test "招待された宛先で受諾すると所属が増える" do
    invitation = create_invitation
    sign_in_as(confirmed_user(INVITED))

    assert_difference -> { Membership.count }, 1 do
      get invitation_path(locale: :ja, token: token(invitation))
    end

    assert_redirected_to organizations_path(locale: :ja)
    assert_predicate invitation.reload, :accepted?
  end

  test "受諾済みのリンクをもう一度たどっても所属が増えない" do
    invitation = create_invitation
    invited = confirmed_user(INVITED)
    sign_in_as(invited)
    used = token(invitation)
    get invitation_path(locale: :ja, token: used)

    assert_no_difference -> { Membership.count } do
      get invitation_path(locale: :ja, token: used)
    end

    assert_response :unprocessable_content
  end

  test "別のメールアドレスでは受諾できない" do
    # 受け入れると、リンクを手にした別人が組織へ入れてしまう。
    invitation = create_invitation
    sign_in_as(confirmed_user("other@example.com"))

    assert_no_difference -> { Membership.count } do
      get invitation_path(locale: :ja, token: token(invitation))
    end

    assert_response :forbidden
  end

  test "未ログインで受諾のリンクをたどるとログイン後に戻る" do
    invitation = create_invitation
    invited = confirmed_user(INVITED)
    path = invitation_path(locale: :ja, token: token(invitation))

    get path

    assert_redirected_to new_session_path(locale: :ja)

    post session_path(locale: :ja), params: { email_address: invited.email_address, password: PASSWORD }

    assert_redirected_to path
  end

  test "期限を過ぎた招待は受諾できない" do
    invitation = create_invitation
    expired = travel_to(Invitation::EXPIRES_IN.ago - 1.minute) { token(invitation) }
    sign_in_as(confirmed_user(INVITED))

    assert_no_difference -> { Membership.count } do
      get invitation_path(locale: :ja, token: expired)
    end

    assert_response :unprocessable_content
  end

  test "壊れた token で例外にならない" do
    sign_in_as(confirmed_user(INVITED))

    get invitation_path(locale: :ja, token: "broken")

    assert_response :unprocessable_content
    assert_select "main h1", text: I18n.t("invitations.invalid.title")
  end

  test "すでに所属している場合は所属を増やさずに成功として扱う" do
    invitation = create_invitation
    invited = confirmed_user(INVITED)
    @organization.memberships.create!(user: invited, role: "member")
    sign_in_as(invited)

    assert_no_difference -> { Membership.count } do
      get invitation_path(locale: :ja, token: token(invitation))
    end

    assert_redirected_to organizations_path(locale: :ja)
  end

  test "招待画面を日本語と英語で表示する" do
    sign_in_as(@owner)

    I18n.available_locales.each do |locale|
      get new_organization_invitation_path(locale: locale, organization_id: @organization)

      assert_response :success
      assert_select "main h1",
        text: I18n.t("invitations.new.title", organization: @organization.name, locale: locale)
    end
  end

  private
    def confirmed_user(email_address)
      User.create!(email_address: email_address, password: PASSWORD).tap(&:confirm)
    end

    def sign_in_as(user)
      post session_path(locale: :ja), params: { email_address: user.email_address, password: PASSWORD }
    end

    def invite(email_address: INVITED, role: "member")
      post organization_invitations_path(locale: :ja, organization_id: @organization),
           params: { invitation: { email_address: email_address, role: role } }
    end

    def create_invitation(email_address: INVITED, role: "member")
      @organization.invitations.create!(email_address: email_address, role: role, invited_by: @owner)
    end

    def token(invitation)
      invitation.reload.generate_token_for(:acceptance)
    end
end
