class AddStructuredSalaryToJobPostings < ActiveRecord::Migration[8.1]
  def change
    # 金額での絞り込みに使う年収の範囲。
    #
    # 自由記述の salary は残す。「経験に応じて相談」のように
    # 金額で表せない条件を書けなくしない。
    # 詳細は docs/decisions/0022-job-posting-salary.md を参照する。
    add_column :job_postings, :annual_salary_min, :integer
    add_column :job_postings, :annual_salary_max, :integer

    # 通貨は 1 つに固定できない。自己ホストの利用者がどの国で使うかを決められない。
    add_column :job_postings, :salary_currency, :string

    # 絞り込みは「この通貨で、この金額以上」で引く。
    add_index :job_postings, [ :salary_currency, :annual_salary_min ]
  end
end
