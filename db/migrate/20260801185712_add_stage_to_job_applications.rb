class AddStageToJobApplications < ActiveRecord::Migration[8.1]
  def change
    # 選考ステージ。応募が生きているか（status）とは別の軸である。
    # 詳細は docs/decisions/0038-selection-stage.md を参照する。
    add_column :job_applications, :stage, :string, null: false, default: "screening"
    add_index :job_applications, [ :job_posting_id, :stage ]

    # 記録は応募の記録と同じ表に置く。
    # 「その応募に何が起きたか」を 2 か所へ分けると、読むときに突き合わせが要る。
    add_column :job_application_events, :from_stage, :string
    add_column :job_application_events, :to_stage, :string
    add_reference :job_application_events, :changed_by,
                  foreign_key: { to_table: :users, on_delete: :nullify }
  end
end
