class CreateJobPostings < ActiveRecord::Migration[8.1]
  def change
    create_table :job_postings do |t|
      # 求人は組織へ従属する。組織が消えたら残さない。
      t.references :organization, null: false, foreign_key: true

      # 公開状態。下書きと公開でレコードを分けない。
      # 詳細は docs/decisions/0016-job-posting-model.md を参照する。
      t.string :status, null: false

      t.string :title, null: false
      t.text :description, null: false

      # 本文は項目に分ける。1 つの自由記述へまとめると、
      # 公開側の検索と表示で毎回解析することになる。
      t.string :location
      t.string :occupation
      t.string :employment_type
      t.string :salary
      t.text :requirements

      t.timestamps
    end

    # 一覧は「この組織の求人を、状態ごとに新しい順」で引く。
    add_index :job_postings, [ :organization_id, :status, :created_at ]
  end
end
