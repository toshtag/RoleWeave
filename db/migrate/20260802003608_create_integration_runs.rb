class CreateIntegrationRuns < ActiveRecord::Migration[8.1]
  def change
    # 外部の識別子。CSV の行と求人を結ぶ。
    # 同じ入力を再実行しても二重に作らないために使う。
    # 詳細は docs/decisions/0058-csv-integration.md を参照する。
    add_column :job_postings, :external_key, :string
    add_index :job_postings, [ :organization_id, :external_key ], unique: true

    # 連携の実行の結果。件数と失敗の内容を残す。
    create_table :integration_runs do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :performed_by, foreign_key: { to_table: :users, on_delete: :nullify }

      t.string :kind, null: false
      t.string :status, null: false, default: "completed"
      t.integer :created_count, null: false, default: 0
      t.integer :updated_count, null: false, default: 0
      t.integer :failed_count, null: false, default: 0
      t.text :failures

      t.timestamps
    end

    add_index :integration_runs, [ :organization_id, :created_at ]
  end
end
