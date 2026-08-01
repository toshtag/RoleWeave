class CreateJobPostingEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :job_posting_events do |t|
      # 対象の求人と組織。どちらも削除されても記録は残す。
      # 「いつからその求人が公開されていたか」は後から復元できない。
      # 詳細は docs/decisions/0018-job-posting-status-history.md を参照する。
      t.references :job_posting, null: true, foreign_key: { on_delete: :nullify }
      t.references :organization, null: true, foreign_key: { on_delete: :nullify }

      # 変更した主体。アカウントが消えても記録は残す。
      t.references :changed_by, null: true, foreign_key: { to_table: :users, on_delete: :nullify }

      # 変更前と変更後の状態。作成のときは変更前を持たない。
      t.string :from_status
      t.string :to_status, null: false

      # 記録した時点の題名。求人が消えた後も、何の記録かが読める状態にする。
      t.string :job_posting_title, null: false

      t.timestamps
    end

    # 調査は「この組織の直近」から始まる。
    add_index :job_posting_events, [ :organization_id, :created_at ]
  end
end
