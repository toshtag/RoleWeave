class OrganizationMailer < ApplicationMailer
  # 組織への招待を知らせる。
  #
  # 表示言語の正本は URL とする契約（ADR 0001）はメールでも維持する。
  # 宛先の言語を推測せず、招待した画面のロケールをそのまま使う。
  def invitation(invitation, locale:)
    @invitation = invitation
    @organization = invitation.organization
    @acceptance_url = invitation_url(
      locale: locale,
      token: invitation.generate_token_for(:acceptance)
    )
    @expires_in_days = Invitation::EXPIRES_IN.in_days.to_i

    I18n.with_locale(locale) do
      mail to: invitation.email_address, subject: t(".subject", organization: @organization.name)
    end
  end
end
