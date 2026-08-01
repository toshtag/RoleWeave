module JobPostingHelper
  # 求人の構造化データ（JSON-LD）。
  #
  # 出すのは入力された項目だけとする。未入力の項目を空で書くと、
  # 「値がない」ではなく「空という値がある」と解釈されうる。
  # 方針は docs/decisions/0024-structured-data-and-crawling.md を正本とする。
  def job_posting_structured_data(job_posting)
    data = {
      "@context" => "https://schema.org",
      "@type" => "JobPosting",
      "title" => job_posting.title,
      "description" => job_posting.description,
      "datePosted" => job_posting.created_at.to_date.iso8601,
      "hiringOrganization" => {
        "@type" => "Organization",
        "name" => job_posting.organization&.name
      }.compact
    }

    data["jobLocation"] = job_location(job_posting) if job_posting.location.present?
    data["employmentType"] = job_posting.employment_type.upcase if job_posting.employment_type.present?
    data["baseSalary"] = base_salary(job_posting) if job_posting.structured_salary?
    data["qualifications"] = job_posting.requirements if job_posting.requirements.present?

    data
  end

  private
    def job_location(job_posting)
      {
        "@type" => "Place",
        "address" => { "@type" => "PostalAddress", "addressLocality" => job_posting.location }
      }
    end

    # 下限だけ、上限だけの求人があるため、両方そろっている前提を置かない。
    def base_salary(job_posting)
      value = { "@type" => "QuantitativeValue", "unitText" => "YEAR" }
      value["minValue"] = job_posting.annual_salary_min if job_posting.annual_salary_min
      value["maxValue"] = job_posting.annual_salary_max if job_posting.annual_salary_max

      {
        "@type" => "MonetaryAmount",
        "currency" => job_posting.salary_currency,
        "value" => value
      }
    end
end
