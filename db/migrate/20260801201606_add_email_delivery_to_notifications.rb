class AddEmailDeliveryToNotifications < ActiveRecord::Migration[8.1]
  def change
    # 配信の状態を通知そのものへ持たせる。
    # 積んだ後に失敗しても、どこにも残らない状態を避ける。
    # 詳細は docs/decisions/0043-notification-delivery-failures.md を参照する。
    add_column :notifications, :email_status, :string, null: false, default: "pending"
    add_column :notifications, :email_attempts, :integer, null: false, default: 0
    add_column :notifications, :email_error, :text
    add_column :notifications, :email_delivered_at, :datetime

    add_index :notifications, :email_status
  end
end
