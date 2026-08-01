# 配信に失敗した通知の一覧と再送。
#
# 運営者だけが扱う。利用者に再送させると、同じ失敗を何度も繰り返させることになる。
# 方針は docs/decisions/0043-notification-delivery-failures.md を正本とする。
class Operator::NotificationDeliveriesController < Operator::BaseController
  def index
    @notifications = Notification.email_failed.includes(:user).recent.limit(100)
  end

  # 再送。通知そのものは作り直さない。
  def update
    notification = Notification.email_failed.find(params[:id])

    notification.update_column(:email_status, "pending")
    NotificationEmailJob.perform_later(notification, locale: I18n.locale)

    redirect_to operator_notification_deliveries_path(locale: I18n.locale)
  end
end
