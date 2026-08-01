class CreateDesiredConditions < ActiveRecord::Migration[8.1]
  def change
    # 希望条件はプロフィールへ 1 対 1 で従属する。
    # 希望年収は企業へ渡す範囲をほかの項目と分けて決める必要があるため、
    # プロフィールの列にはしない。
    # 詳細は docs/decisions/0029-desired-condition-and-completeness.md を参照する。
    create_table :desired_conditions do |t|
      t.references :candidate_profile, null: false, foreign_key: true, index: { unique: true }

      # 雇用形態と通貨は求人と同じ語彙を使う。食い違うと突き合わせができない。
      t.string :employment_type
      t.string :salary_currency
      t.integer :annual_salary_min

      t.string :location
      t.date :available_from
      t.text :note

      t.timestamps
    end
  end
end
