# 利用者が自分のデータを持ち出すための組み立て。
#
# 何を出すかを、ここ 1 か所で決める。
# 列を足したときに黙って出る／黙って出ないの両方を避けるため、
# 出す列と出さない列を明示し、テストで網羅を確かめる。
# 方針は docs/decisions/0032-personal-data-export.md を正本とする。
class ProfileExport
  # 出さない列。理由をそれぞれ書く。
  #
  # 本人へ返す意味がなく、渡った先で悪用されうるものを外す。
  EXCLUDED_COLUMNS = {
    "users" => {
      "id" => "内部の識別子であり、本人にとって意味がない",
      "password_digest" => "パスワードのハッシュ。渡った先で総当たりの材料になる",
      "operator" => "運営者かどうかは、このサーバーの運用の情報である"
    },
    "candidate_profiles" => {
      "id" => "内部の識別子であり、本人にとって意味がない",
      "user_id" => "内部の識別子であり、本人にとって意味がない"
    }
  }.freeze

  # 出す列。
  EXPORTED_COLUMNS = {
    # メールの受け取りの設定も本人が決めたものであり、本人のデータとして出す。
    "users" => %w[email_address confirmed_at email_notifications created_at updated_at],
    "candidate_profiles" => %w[display_name introduction location desired_occupation
                               visibility desired_salary_visible documents_visible
                               created_at updated_at]
  }.freeze

  def initialize(user)
    @user = user
  end

  def to_h
    {
      exported_at: Time.current,
      account: account,
      candidate_profile: candidate_profile,
      memberships: memberships
    }
  end

  def to_json(*)
    JSON.pretty_generate(to_h.as_json)
  end

  def filename
    "roleweave-export-#{Time.current.strftime("%Y%m%d")}.json"
  end

  private
    def account
      @user.slice(*EXPORTED_COLUMNS.fetch("users"))
    end

    def candidate_profile
      profile = @user.candidate_profile
      return nil if profile.nil?

      profile.slice(*EXPORTED_COLUMNS.fetch("candidate_profiles")).merge(
        "work_experiences" => work_experiences(profile),
        "educations" => educations(profile),
        "skills" => skills(profile),
        "desired_condition" => desired_condition(profile),
        # 添付は名前・大きさ・形式だけを出す。中身は本人の画面から取れる。
        "documents" => documents(profile)
      )
    end

    def work_experiences(profile)
      profile.work_experiences.recent.map do |work_experience|
        work_experience.slice("organization_name", "position", "description", "started_on", "ended_on")
      end
    end

    def educations(profile)
      profile.educations.recent.map do |education|
        education.slice("school_name", "field_of_study", "degree", "started_on", "ended_on")
      end
    end

    def skills(profile)
      profile.skills.alphabetical.map { |skill| skill.slice("name", "years_of_experience") }
    end

    def desired_condition(profile)
      profile.desired_condition&.slice("employment_type", "salary_currency", "annual_salary_min",
                                       "location", "available_from", "note")
    end

    def documents(profile)
      CandidateProfile::DOCUMENT_KINDS.filter_map do |kind|
        attachment = profile.public_send(kind)
        next unless attachment.attached?

        {
          "kind" => kind,
          "filename" => attachment.filename.to_s,
          "byte_size" => attachment.byte_size,
          "content_type" => attachment.content_type
        }
      end
    end

    # 所属も本人のデータである。どの組織にいつ入り、どの役割かを出す。
    def memberships
      @user.memberships.includes(:organization).map do |membership|
        {
          "organization_name" => membership.organization.name,
          "role" => membership.role,
          "joined_at" => membership.created_at
        }
      end
    end
end
