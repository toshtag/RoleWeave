class AddSavedSearchToNotifications < ActiveRecord::Migration[8.1]
  def change
    # 新着の求人の通知。どの条件に何件一致したかを持つ。
    # 詳細は docs/decisions/0054-saved-searches.md を参照する。
    add_reference :notifications, :saved_search, foreign_key: { on_delete: :cascade }
    add_column :notifications, :new_job_postings_count, :integer
  end
end
