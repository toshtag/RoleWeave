class CreateApplicationReviews < ActiveRecord::Migration[8.1]
  def change
    # 応募への評価とコメント。社内の判断の材料であり、応募者には見せない。
    # 詳細は docs/decisions/0039-application-review-and-assignment.md を参照する。
    create_table :application_reviews do |t|
      t.references :job_application, null: false, foreign_key: true
      # 記録した人。削除しても記録は残す。
      t.references :reviewer, foreign_key: { to_table: :users, on_delete: :nullify }

      t.integer :rating
      t.text :comment

      t.timestamps
    end

    add_index :application_reviews, [ :job_application_id, :created_at ]

    # 応募の担当者。所属者の中から選ぶ。
    add_reference :job_applications, :assignee,
                  foreign_key: { to_table: :users, on_delete: :nullify }
  end
end
