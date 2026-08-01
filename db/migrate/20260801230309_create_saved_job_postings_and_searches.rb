class CreateSavedJobPostingsAndSearches < ActiveRecord::Migration[8.1]
  def change
    # 気になる求人の保存。
    # 詳細は docs/decisions/0054-saved-searches.md を参照する。
    create_table :saved_job_postings do |t|
      t.references :candidate_profile, null: false, foreign_key: true
      t.references :job_posting, null: false, foreign_key: true

      t.timestamps
    end

    # 同じ求人を 2 回保存しても意味がない。
    add_index :saved_job_postings, [ :candidate_profile_id, :job_posting_id ], unique: true

    # 保存した検索条件と、新着の通知の状態。
    create_table :saved_searches do |t|
      t.references :candidate_profile, null: false, foreign_key: true

      t.string :name, null: false
      t.jsonb :conditions, null: false, default: {}
      t.boolean :notify, null: false, default: true
      # ここより後に公開された求人だけを通知する。同じ求人を 2 回通知しない。
      t.datetime :notified_at

      t.timestamps
    end

    add_index :saved_searches, [ :candidate_profile_id, :created_at ]
  end
end
