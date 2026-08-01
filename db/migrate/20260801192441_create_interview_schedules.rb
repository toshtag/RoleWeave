class CreateInterviewSchedules < ActiveRecord::Migration[8.1]
  def change
    # 面接の予定。社内の予定として持つ。応募者へは伝わらない。
    # 詳細は docs/decisions/0040-interview-schedule-and-deadline.md を参照する。
    create_table :interview_schedules do |t|
      t.references :job_application, null: false, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users, on_delete: :nullify }

      t.datetime :starts_at, null: false
      t.integer :duration_minutes
      t.string :location
      t.text :note

      t.string :status, null: false, default: "scheduled"

      t.timestamps
    end

    add_index :interview_schedules, [ :job_application_id, :starts_at ]

    # 結論を出す期限。任意とする。
    add_column :job_applications, :decide_by, :date
  end
end
