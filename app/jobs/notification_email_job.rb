# 通知メールを送り、成功と失敗を記録するジョブ。
#
# `deliver_later` を直接使わない。積んだ後の結果がどこにも残らないためである。
# 例外は握り潰さない。握り潰すと、ジョブの再試行が働かなくなる。
# 方針は docs/decisions/0043-notification-delivery-failures.md を正本とする。
class NotificationEmailJob < ApplicationJob
  queue_as :default

  def perform(notification, locale:)
    mail = build_mail(notification, locale)

    mail.deliver_now

    notification.record_email_delivered!
  rescue StandardError => error
    # 失敗の内容をそのまま残す。運営者が原因を追えるようにする。
    notification.record_email_failure!(error)

    raise
  end

  private
    def build_mail(notification, locale)
      case notification.kind
      when "message_received" then NotificationMailer.message_received(notification, locale: locale)
      when "stage_changed" then NotificationMailer.stage_changed(notification, locale: locale)
      else raise ArgumentError, "未知の通知の種類: #{notification.kind}"
      end
    end
end
