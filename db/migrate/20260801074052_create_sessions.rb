class CreateSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :sessions do |t|
      # セッションはアカウントへ従属する。アカウントが消えたら残さない。
      # 外部キーを張り、参照先のないセッションが残る状態を作らない。
      # 詳細は docs/decisions/0007-database-backed-sessions.md を参照する。
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
