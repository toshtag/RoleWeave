require "test_helper"

# 組織の作成と一覧の契約を検証する。
#
# 検証対象は、誰が作成できるか、作成した結果どうなるか、
# そして一覧に何が出るかである。
class OrganizationCreationTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct horse battery".freeze
  NAME = "Example Inc.".freeze

  setup do
    @user = User.create!(email_address: "member@example.com", password: PASSWORD)
  end

  test "未ログインでは組織を作成できない" do
    assert_no_difference -> { Organization.count } do
      post organizations_path(locale: :ja), params: { organization: { name: NAME } }
    end

    assert_redirected_to new_session_path(locale: :ja)
  end

  test "メールアドレスが未確認では組織を作成できない" do
    sign_in

    assert_no_difference -> { Organization.count } do
      get new_organization_path(locale: :ja)
    end

    assert_response :forbidden
  end

  test "組織を作成すると作成者が owner になる" do
    confirmed_sign_in

    assert_difference -> { Organization.count }, 1 do
      create_organization
    end

    membership = Organization.last.memberships.sole

    assert_equal @user, membership.user
    assert_predicate membership, :owner?
  end

  test "作成後に一覧へ遷移する" do
    confirmed_sign_in

    create_organization

    assert_redirected_to organizations_path(locale: :ja)
  end

  test "名前が空だと作成できない" do
    confirmed_sign_in

    assert_no_difference -> { Organization.count } do
      create_organization(name: "  ")
    end

    assert_response :unprocessable_content
    assert_select "main h1", text: I18n.t("organizations.new.title")
  end

  test "所属を持たない組織が残らない" do
    # 作成に失敗しても、誰も入れない組織を残さない。
    # 巻き戻し自体は organization_test が Organization.create_with_owner! で確認する。
    confirmed_sign_in
    create_organization
    create_organization(name: "  ")

    assert_empty Organization.where.missing(:memberships)
  end

  test "自分が所属する組織だけが一覧に出る" do
    # すべての組織を出すと、一覧そのものが登録済みの組織を調べる手段になる。
    confirmed_sign_in
    create_organization

    other = User.create!(email_address: "other@example.com", password: PASSWORD)
    Organization.create!(name: "Another Inc.").memberships.create!(user: other, role: "owner")

    get organizations_path(locale: :ja)

    # 項目には組織名のほかに導線も並ぶため、部分一致で確かめる。
    assert_select "main li", text: /#{Regexp.escape(NAME)}/, count: 1
    assert_select "main li", text: /Another Inc\./, count: 0
  end

  test "所属がないときは一覧が空であることを伝える" do
    confirmed_sign_in

    get organizations_path(locale: :ja)

    assert_response :success
    assert_select "main p", text: I18n.t("organizations.index.empty")
  end

  test "作成画面と一覧を日本語と英語で表示する" do
    confirmed_sign_in

    I18n.available_locales.each do |locale|
      get new_organization_path(locale: locale)

      assert_response :success
      assert_select "main h1", text: I18n.t("organizations.new.title", locale: locale)

      get organizations_path(locale: locale)

      assert_response :success
      assert_select "main h1", text: I18n.t("organizations.index.title", locale: locale)
    end
  end

  private
    def sign_in(locale: :ja)
      post session_path(locale: locale), params: { email_address: @user.email_address, password: PASSWORD }
    end

    def confirmed_sign_in
      @user.confirm
      sign_in
    end

    def create_organization(name: NAME)
      post organizations_path(locale: :ja), params: { organization: { name: name } }
    end
end
