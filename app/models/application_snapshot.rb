# 応募時点の求人とプロフィールの写し。
#
# 何を残すかを、ここ 1 か所で決める。
# 内部の識別子は残さない。別の環境へ移したときに意味を持たず、
# 残しても「応募時に何を見たか」の説明にならない。
# 方針は docs/decisions/0034-job-application.md を正本とする。
class ApplicationSnapshot
  # 求人から写す項目。組織名は求人の側にないため、別に足す。
  JOB_POSTING_COLUMNS = %w[title description requirements location occupation
                           employment_type salary salary_currency
                           annual_salary_min annual_salary_max].freeze

  PROFILE_COLUMNS = %w[display_name introduction location desired_occupation].freeze

  def self.of_job_posting(job_posting)
    job_posting.slice(*JOB_POSTING_COLUMNS).merge(
      "organization_name" => job_posting.organization.name,
      "published_at" => job_posting.updated_at
    )
  end

  def self.of_candidate_profile(candidate_profile)
    candidate_profile.slice(*PROFILE_COLUMNS).merge(
      "work_experiences" => work_experiences(candidate_profile),
      "educations" => educations(candidate_profile),
      "skills" => skills(candidate_profile),
      "desired_condition" => desired_condition(candidate_profile),
      "documents" => documents(candidate_profile)
    )
  end

  def self.work_experiences(candidate_profile)
    candidate_profile.work_experiences.recent.map do |work_experience|
      work_experience.slice("organization_name", "position", "description", "started_on", "ended_on")
    end
  end

  def self.educations(candidate_profile)
    candidate_profile.educations.recent.map do |education|
      education.slice("school_name", "field_of_study", "degree", "started_on", "ended_on")
    end
  end

  def self.skills(candidate_profile)
    candidate_profile.skills.alphabetical.map { |skill| skill.slice("name", "years_of_experience") }
  end

  # 希望年収は、本人が見せる設定にしているときだけ写す。
  # 応募したことと、希望年収を明かすことは別の判断である（ADR 0030）。
  def self.desired_condition(candidate_profile)
    desired_condition = candidate_profile.desired_condition
    return nil if desired_condition.nil?

    columns = %w[employment_type location available_from note]
    columns += %w[salary_currency annual_salary_min] if candidate_profile.desired_salary_visible?

    desired_condition.slice(*columns)
  end

  # 添付は名前・大きさ・形式だけを写す。実体は Active Storage が持つ。
  def self.documents(candidate_profile)
    CandidateProfile::DOCUMENT_KINDS.filter_map do |kind|
      attachment = candidate_profile.public_send(kind)
      next unless attachment.attached?

      { "kind" => kind, "filename" => attachment.filename.to_s,
        "byte_size" => attachment.byte_size, "content_type" => attachment.content_type }
    end
  end

  private_class_method :work_experiences, :educations, :skills, :desired_condition, :documents
end
