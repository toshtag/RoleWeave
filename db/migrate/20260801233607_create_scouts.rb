class CreateScouts < ActiveRecord::Migration[8.1]
  def change
    # 企業から候補者への働きかけ。
    # 詳細は docs/decisions/0056-scouting.md を参照する。
    create_table :scouts do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :candidate_profile, null: false, foreign_key: true
      t.references :sent_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.references :job_posting, foreign_key: { on_delete: :nullify }

      t.text :body, null: false

      t.timestamps
    end

    # 同じ組織から同じ候補者へ 2 通目を送れない。
    add_index :scouts, [ :organization_id, :candidate_profile_id ], unique: true
    add_index :scouts, [ :organization_id, :created_at ]

    # 組織で共有するテンプレート。
    create_table :scout_templates do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :name, null: false
      t.text :body, null: false

      t.timestamps
    end

    add_index :scout_templates, [ :organization_id, :name ], unique: true

    # 候補者による組織ごとの配信停止。
    create_table :scout_blocks do |t|
      t.references :candidate_profile, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true

      t.timestamps
    end

    add_index :scout_blocks, [ :candidate_profile_id, :organization_id ], unique: true
  end
end
