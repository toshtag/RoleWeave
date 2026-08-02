class AddScoutToNotifications < ActiveRecord::Migration[8.1]
  def change
    # スカウトの受信の通知。
    # 詳細は docs/decisions/0056-scouting.md を参照する。
    add_reference :notifications, :scout, foreign_key: { on_delete: :cascade }
  end
end
