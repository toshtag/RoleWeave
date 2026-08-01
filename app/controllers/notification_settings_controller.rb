# メールの受け取りの設定。
#
# アプリ内の通知はこの設定によらず作る。止めるのはメールだけである。
# 方針は docs/decisions/0042-notifications.md を正本とする。
class NotificationSettingsController < ApplicationController
  before_action :require_authentication
  before_action :require_confirmed_email

  def edit
  end

  def update
    current_user.update!(email_notifications: params[:email_notifications] == "1")

    redirect_to account_path(locale: I18n.locale)
  end
end
