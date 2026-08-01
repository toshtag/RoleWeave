class CreateWorkExperiences < ActiveRecord::Migration[8.1]
  def change
    create_table :work_experiences do |t|
      # 職歴はプロフィールへ従属する。プロフィールが消えたら残さない。
      # 詳細は docs/decisions/0027-work-experience.md を参照する。
      t.references :candidate_profile, null: false, foreign_key: true

      t.string :organization_name, null: false
      t.string :position, null: false
      t.text :description

      t.date :started_on, null: false
      # 終了日は任意とする。空であれば在籍中として扱う。
      # 必須にすると、在籍中を表せないか、未来の日付を入れることになる。
      t.date :ended_on

      t.timestamps
    end

    # 一覧は「このプロフィールの職歴を、開始日の新しい順」で引く。
    add_index :work_experiences, [ :candidate_profile_id, :started_on ]
  end
end
