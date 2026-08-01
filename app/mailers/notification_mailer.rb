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

  def stage_changed(notification, locale:)
    @job_application = notification.job_application
    @application_url = profile_application_url(locale: locale, id: @job_application)

    I18n.with_locale(locale) do
      mail to: notification.user.email_address, subject: t(".subject")
    end
  end
end
