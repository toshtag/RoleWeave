class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    # アプリ内通知。設定によらず作る。設定はメールの送信だけを止める。
    # 詳細は docs/decisions/0042-notifications.md を参照する。
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.references :job_application, foreign_key: { on_delete: :cascade }
      t.references :message, foreign_key: { on_delete: :cascade }

      t.string :kind, null: false
      t.datetime :read_at

      t.timestamps
    end

    add_index :notifications, [ :user_id, :created_at ]

    # メールの受け取り。既定は受け取る。
    add_column :users, :email_notifications, :boolean, null: false, default: true
  end
end
