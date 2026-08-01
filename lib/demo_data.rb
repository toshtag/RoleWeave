# 評価のための架空データ。
#
# **架空であることを、データそのものから分かるようにする。**
# メールアドレスは RFC 2606 が予約する `.invalid` を使う。実在しない領域である。
# 実在しそうな値を使うと、デモのつもりで作ったデータが本物と混ざる。
# 方針は docs/decisions/0051-demo-data.md を正本とする。
class DemoData
  PASSWORD = "demo password 1234".freeze
  DOMAIN = "example.invalid".freeze

  # 架空と分かる名前にする。実在する会社名・人名を使わない。
  ORGANIZATION_NAME = "デモ株式会社".freeze

  ACCOUNTS = {
    candidate: { email: "candidate@#{DOMAIN}", display_name: "デモ 太郎" },
    another_candidate: { email: "candidate2@#{DOMAIN}", display_name: "デモ 花子" },
    owner: { email: "owner@#{DOMAIN}" },
    member: { email: "member@#{DOMAIN}" },
    operator: { email: "operator@#{DOMAIN}" }
  }.freeze

  def seed
    raise "デモデータは development でのみ投入できる" unless Rails.env.development?

    return "デモデータはすでに投入されている（#{summary}）" if seeded?

    ActiveRecord::Base.transaction do
      create_accounts
      create_job_postings
      create_applications
      advance_selection
      create_conversation
    end

    "デモデータを投入した（#{summary}）"
  end

  def clean
    raise "デモデータは development でのみ削除できる" unless Rails.env.development?

    users = User.where("email_address LIKE ?", "%@#{DOMAIN}")
    organization = Organization.find_by(name: ORGANIZATION_NAME)

    count = users.count
    users.destroy_all
    organization&.job_postings&.destroy_all
    organization&.destroy

    "デモデータを消した（アカウント #{count} 件）"
  end

  def seeded?
    User.exists?(email_address: ACCOUNTS[:candidate][:email])
  end

  def summary
    "アカウント #{User.where("email_address LIKE ?", "%@#{DOMAIN}").count} 件 / " \
      "求人 #{JobPosting.count} 件 / 応募 #{JobApplication.count} 件"
  end

  private
    def create_accounts
      @candidate = create_user(ACCOUNTS[:candidate])
      @another_candidate = create_user(ACCOUNTS[:another_candidate])
      @owner = create_user(ACCOUNTS[:owner])
      @member = create_user(ACCOUNTS[:member])
      @operator = create_user(ACCOUNTS[:operator])
      @operator.update!(operator: true)

      @organization = Organization.create_with_owner!(name: ORGANIZATION_NAME, user: @owner)
      Membership.create!(organization: @organization, user: @member, role: "member")

      @profile = build_profile(@candidate, ACCOUNTS[:candidate][:display_name])
      @another_profile = build_profile(@another_candidate, ACCOUNTS[:another_candidate][:display_name])
    end

    def create_user(account)
      User.create!(email_address: account[:email], password: PASSWORD).tap(&:confirm)
    end

    # 画面が空にならないよう、職歴・学歴・スキル・希望条件まで入れる。
    def build_profile(user, display_name)
      profile = user.create_candidate_profile!(
        display_name: display_name,
        introduction: "デモ用の自己紹介です。実在の人物ではありません。",
        location: "東京",
        desired_occupation: "採用担当",
        visibility: "applied_organizations"
      )

      profile.work_experiences.create!(
        organization_name: "架空商事", position: "採用担当",
        description: "デモ用の職歴です。", started_on: Date.new(2020, 4, 1), ended_on: Date.new(2024, 3, 31)
      )
      profile.educations.create!(school_name: "架空大学", field_of_study: "経営学",
                                 started_on: Date.new(2016, 4, 1), ended_on: Date.new(2020, 3, 31))
      profile.skills.create!(name: "採用計画", years_of_experience: 4)
      profile.skills.create!(name: "面接", years_of_experience: 3)
      profile.create_desired_condition!(employment_type: "full_time", location: "東京",
                                        salary_currency: "JPY", annual_salary_min: 5_000_000)

      profile
    end

    # 公開中だけでなく、下書きと審査中も入れる。状態の違いが画面で見える。
    def create_job_postings
      @published = @organization.job_postings.create!(
        title: "採用担当（デモ）", description: "デモ用の求人です。実在の募集ではありません。",
        requirements: "採用の実務経験", location: "東京", occupation: "人事",
        employment_type: "full_time", salary_currency: "JPY",
        annual_salary_min: 5_000_000, annual_salary_max: 7_000_000,
        status: "published", changed_by: @owner
      )
      @organization.job_postings.create!(
        title: "エンジニア（デモ・下書き）", description: "デモ用の下書きです。",
        status: "draft", changed_by: @member
      )
      @organization.job_postings.create!(
        title: "デザイナー（デモ・審査中）", description: "デモ用の審査中の求人です。",
        status: "pending_review", changed_by: @member
      )
    end

    def create_applications
      @application = @profile.job_applications.create!(job_posting: @published)
      @another_application = @another_profile.job_applications.create!(job_posting: @published)
    end

    # 選考が進んだ応募を 1 件作る。段階の違いが画面で見える。
    def advance_selection
      @application.move_to("interviewing", changed_by: @owner)
      @application.application_reviews.create!(reviewer: @member, rating: 4,
                                               comment: "デモ用の評価です。")
      @application.interview_schedules.create!(created_by: @owner, starts_at: 3.days.from_now,
                                               duration_minutes: 60, location: "オンライン")
      @application.update!(assignee: @member, decide_by: Date.current + 14)
    end

    def create_conversation
      conversation = Conversation.create!(job_application: @application)
      conversation.messages.create!(sender: @owner, body: "デモ用のメッセージです。面接の日程をご相談させてください。")
      conversation.messages.create!(sender: @candidate, body: "デモ用の返信です。よろしくお願いします。")
    end
end
