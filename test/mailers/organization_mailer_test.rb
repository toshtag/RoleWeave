require "test_helper"

# 招待メールの契約を検証する。
#
# 検証対象は宛先、言語、URL、含めてはならない情報である。
class OrganizationMailerTest < ActionMailer::TestCase
  setup do
    @organization = Organization.create!(name: "Example Inc.")
    @inviter = User.create!(email_address: "owner@example.com", password: "correct horse battery")
    @organization.memberships.create!(user: @inviter, role: "owner")
    @invitation = @organization.invitations.create!(
      email_address: "invited@example.com",
      role: "member",
      invited_by: @inviter
    )
  end

  test "招待した宛先へ送る" do
    mail = OrganizationMailer.invitation(@invitation, locale: :ja)

    assert_equal [ @invitation.email_address ], mail.to
  end

  test "件名と本文をロケールの言語で書く" do
    # 宛先の言語を推測せず、招待した画面のロケールをそのまま使う。
    I18n.available_locales.each do |locale|
      mail = OrganizationMailer.invitation(@invitation, locale: locale)

      assert_equal(
        I18n.t("organization_mailer.invitation.subject", organization: @organization.name, locale: locale),
        mail.subject
      )
      assert_includes mail.body.to_s, I18n.t("organization_mailer.invitation.body", locale: locale)
    end
  end

  test "そのロケールの受諾 URL を含む" do
    I18n.available_locales.each do |locale|
      mail = OrganizationMailer.invitation(@invitation, locale: locale)

      assert_match %r{/#{locale}/invitation/}, mail.body.to_s
    end
  end

  test "本文の URL で受諾できる" do
    # URL を組み立てる場所と、受け取る場所が食い違っていないことを確認する。
    mail = OrganizationMailer.invitation(@invitation, locale: :ja)
    token = mail.body.to_s[%r{/ja/invitation/(\S+)}, 1]

    assert_equal @invitation, Invitation.find_by_token_for(:acceptance, token)
  end

  test "組織名を本文へ含める" do
    # どの組織からの招待かが分からないと、受け入れてよいか判断できない。
    mail = OrganizationMailer.invitation(@invitation, locale: :ja)

    assert_includes mail.body.to_s, @organization.name
  end

  test "呼び出しの後にロケールを残さない" do
    OrganizationMailer.invitation(@invitation, locale: :en).deliver_now

    assert_equal I18n.default_locale, I18n.locale
  end
end
