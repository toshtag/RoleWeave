class CreateConversations < ActiveRecord::Migration[8.1]
  def change
    # 会話は応募に 1 つ。相手は応募によって決まる。
    # 詳細は docs/decisions/0041-application-conversation.md を参照する。
    create_table :conversations do |t|
      t.references :job_application, null: false, foreign_key: true, index: { unique: true }

      t.timestamps
    end

    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true
      # 送信者を削除してもメッセージは残す。誰が書いたかは失われる。
      t.references :sender, foreign_key: { to_table: :users, on_delete: :nullify }

      t.text :body, null: false

      t.timestamps
    end

    add_index :messages, [ :conversation_id, :created_at ]

    # 既読。誰がどのメッセージを読んだかを行として持つ。
    create_table :message_reads do |t|
      t.references :message, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    # 同じ人が同じメッセージを二重に読んだ記録は持たない。
    add_index :message_reads, [ :message_id, :user_id ], unique: true
  end
end
