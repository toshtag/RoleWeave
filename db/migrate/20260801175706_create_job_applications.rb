class CreateJobApplications < ActiveRecord::Migration[8.1]
  def change
    # 応募。求職者のプロフィールと求人を結ぶ。
    # 詳細は docs/decisions/0034-job-application.md を参照する。
    create_table :job_applications do |t|
      t.references :candidate_profile, null: false, foreign_key: true
      t.references :job_posting, null: false, foreign_key: true

      t.string :status, null: false, default: "submitted"

      # 応募時点の求人とプロフィール。
      #
      # 求人もプロフィールも後から変わる。現在の値を出すと、
      # 「応募時に何を見て、何を出したか」を双方が確かめられない。
      t.jsonb :job_posting_snapshot, null: false, default: {}
      t.jsonb :candidate_profile_snapshot, null: false, default: {}

      t.timestamps
    end

    # 同じ求職者が同じ求人へ 2 回応募することを、データベースの側でも拒否する。
    add_index :job_applications, [ :candidate_profile_id, :job_posting_id ], unique: true
  end
end
