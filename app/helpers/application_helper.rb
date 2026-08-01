module ApplicationHelper
  # 項目ごとの誤りの説明へ与える id。
  #
  # 誤りがない項目では nil を返す。存在しない id を aria-describedby へ書くと、
  # 支援技術が解決できない参照になる。
  def field_error_id(record, attribute)
    return if record.errors[attribute].empty?

    "#{record.model_name.param_key}_#{attribute}_error"
  end

  # 構造化された年収の範囲を、読める 1 行にする。
  #
  # 下限だけ、上限だけの求人があるため、両方そろっている前提を置かない。
  # 金額を持たない求人では nil を返し、行ごと出さない。
  def annual_salary_range(job_posting)
    return unless job_posting.structured_salary?

    currency = t("job_postings.salary_currencies.#{job_posting.salary_currency}")
    minimum = job_posting.annual_salary_min
    maximum = job_posting.annual_salary_max

    amount =
      if minimum && maximum
        "#{number_with_delimiter(minimum)}〜#{number_with_delimiter(maximum)}"
      elsif minimum
        t("job_postings.salary_from", amount: number_with_delimiter(minimum))
      else
        t("job_postings.salary_up_to", amount: number_with_delimiter(maximum))
      end

    "#{amount} #{currency}"
  end
end
