# 通知のメール。
#
# 本文に中身（メッセージの本文・評価・面接の予定・経歴）を書かない。
# メールは転送も保存もされる経路であり、公開範囲の設定が効かない（ADR 0037 と同じ理由）。
# 方針は docs/decisions/0042-notifications.md を正本とする。
class NotificationMailer < ApplicationMailer
  def message_received(notification, locale:)
    @job_application = notification.job_application
    @conversation_url = application_conversation_url(
      locale: locale, application_id: @job_application
    )

    I18n.with_locale(locale) do
      mail to: notification.user.email_address, subject: t(".subject")
    end
  end

# 新着の求人。件数だけを伝え、求人の中身は書かない。
def new_job_postings(notification, locale:)
  @saved_search = notification.saved_search
  @count = notification.new_job_postings_count
  @jobs_url = public_job_postings_url(locale: locale, **(@saved_search&.conditions || {}).symbolize_keys)

  I18n.with_locale(locale) do
    mail to: notification.user.email_address, subject: t(".subject", count: @count)
  end
end

# スカウトの受信。本文は書かない。読むにはアプリを開いてもらう。
def scout_received(notification, locale:)
  @organization_name = notification.scout&.organization&.name
  @scouts_url = profile_scouts_url(locale: locale)

  I18n.with_locale(locale) do
    mail to: notification.user.email_address, subject: t(".subject")
  end
end

  def stage_changed(notification, locale:)
    @job_application = notification.job_application
    @application_url = profile_application_url(locale: locale, id: @job_application)

    I18n.with_locale(locale) do
      mail to: notification.user.email_address, subject: t(".subject")
    end
  end
end
