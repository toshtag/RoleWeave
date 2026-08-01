# 自分への通知の一覧。
#
# 対象は常にログインしている本人とする。ID を受け取らない。
# 方針は docs/decisions/0042-notifications.md を正本とする。
class NotificationsController < ApplicationController
  before_action :require_authentication
  before_action :require_confirmed_email

  def index
    @notifications = current_user.notifications.includes(:job_application).recent.limit(100)

    # 開いた時点で既読にする。読んだ後の一覧を出すため、既読にしてから読み出す。
    Notification.mark_all_read(current_user)
  end
end
