class CreateEducationsAndSkills < ActiveRecord::Migration[8.1]
  def change
    # 学歴と職歴は同じ形をしている。期間の規則は HasPeriod が持つ。
    # 詳細は docs/decisions/0028-education-and-skill.md を参照する。
    create_table :educations do |t|
      t.references :candidate_profile, null: false, foreign_key: true

      t.string :school_name, null: false
      t.string :field_of_study
      t.string :degree

      t.date :started_on, null: false
      # 終了日は任意とする。空であれば在学中として扱う。
      t.date :ended_on

      t.timestamps
    end

    add_index :educations, [ :candidate_profile_id, :started_on ]

    create_table :skills do |t|
      t.references :candidate_profile, null: false, foreign_key: true

      t.string :name, null: false
      # 経験年数は任意とする。書けない・書きたくない場合がある。
      t.integer :years_of_experience

      t.timestamps
    end

    # 同じスキルが 2 つ並ぶと、読み手はどちらが正しいか判断できない。
    # 検証を迂回した重複もデータベースの側で拒否する。
    add_index :skills, [ :candidate_profile_id, :name ], unique: true
  end
end
