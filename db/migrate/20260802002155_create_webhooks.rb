class CreateWebhooks < ActiveRecord::Migration[8.1]
  def change
    # 外部への配信先。どこへ送るかは利用者が決める。
    # 詳細は docs/decisions/0057-webhooks.md を参照する。
    create_table :webhooks do |t|
      t.references :organization, null: false, foreign_key: true

      t.string :url, null: false
      # 本文の署名に使う。画面には登録時しか出さない。
      t.string :secret, null: false
      # 送る出来事の種類。選んでいない種類は送らない。
      t.string :event_kinds, null: false, array: true, default: []
      t.boolean :enabled, null: false, default: true

      t.timestamps
    end

    add_index :webhooks, [ :organization_id, :url ], unique: true

    # 配信の結果。失敗を追えるようにする。
    create_table :webhook_deliveries do |t|
      t.references :webhook, null: false, foreign_key: true

      t.string :event_kind, null: false
      t.string :status, null: false, default: "pending"
      t.integer :response_code
      t.integer :attempts, null: false, default: 0
      t.text :error
      t.datetime :delivered_at

      t.timestamps
    end

    add_index :webhook_deliveries, [ :webhook_id, :created_at ]
  end
end
