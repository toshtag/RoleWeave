class CreateJobApplicationEvents < ActiveRecord::Migration[8.1]
  def change
    # 応募と取消の記録。
    #
    # 応募そのものはプロフィールの削除で消える（ADR 0034）。
    # 企業側に残る記録は、この表が持つ。
    # 詳細は docs/decisions/0037-job-application-events-and-notification.md を参照する。
    create_table :job_application_events do |t|
      # 参照は消えうる。記録そのものは残す。
      t.references :job_application, foreign_key: { on_delete: :nullify }
      t.references :organization, null: false, foreign_key: true
      t.references :job_posting, foreign_key: { on_delete: :nullify }

      t.string :kind, null: false

      # 参照が消えた後も、何の応募だったかを読めるようにする。
      t.string :job_posting_title, null: false
      t.string :candidate_display_name, null: false

      t.timestamps
    end

    add_index :job_application_events, [ :organization_id, :created_at ]
  end
end
