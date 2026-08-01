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

  # 応募が届いたことを知らせる。
  #
  # 本文に応募者の経歴を書かない。メールは転送も保存もされる経路であり、
  # 公開範囲の設定が効かない場所へ個人情報を写すことになる。
  # 詳細は docs/decisions/0037-job-application-events-and-notification.md を参照する。
  def job_application(job_application, to:, locale:)
    @job_posting_title = job_application.job_posting_snapshot["title"]
    @organization = job_application.job_posting.organization
    @applications_url = organization_job_posting_applications_url(
      locale: locale,
      organization_id: @organization,
      job_posting_id: job_application.job_posting
    )

    I18n.with_locale(locale) do
      mail to: to, subject: t(".subject", title: @job_posting_title)
    end
  end
end
