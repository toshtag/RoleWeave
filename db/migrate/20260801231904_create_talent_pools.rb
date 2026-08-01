class CreateTalentPools < ActiveRecord::Migration[8.1]
  def change
    # 求職者による受信の許可。既定は false とする。
    # 「応募した企業に見せる」と「探されて一覧に並ぶ」は同じ同意ではない（ADR 0030）。
    # 詳細は docs/decisions/0055-candidate-search.md を参照する。
    add_column :candidate_profiles, :scout_opt_in, :boolean, null: false, default: false
    add_index :candidate_profiles, :scout_opt_in

    # 企業が候補者を保存しておく場所。組織の中で共有する。
    create_table :talent_pools do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :name, null: false

      t.timestamps
    end

    add_index :talent_pools, [ :organization_id, :name ], unique: true

    create_table :talent_pool_members do |t|
      t.references :talent_pool, null: false, foreign_key: true
      t.references :candidate_profile, null: false, foreign_key: true
      t.references :added_by, foreign_key: { to_table: :users, on_delete: :nullify }

      t.timestamps
    end

    # 同じ候補者を同じプールへ 2 回入れても意味がない。
    add_index :talent_pool_members, [ :talent_pool_id, :candidate_profile_id ], unique: true
  end
end
