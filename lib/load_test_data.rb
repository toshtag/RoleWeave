# 負荷試験のためのデータ。
#
# 本番のデータと混ざらないよう、専用の印（メールアドレスと組織名）を付ける。
# 方針は docs/decisions/0050-capacity-model.md を正本とする。
class LoadTestData
  MARKER = "loadtest".freeze
  ORGANIZATION_NAME = "負荷試験の組織".freeze
  PASSWORD = "correct horse battery staple".freeze

  def seed(job_postings:)
    organization = find_or_create_organization
    created = 0

    job_postings.times do |index|
      organization.job_postings.create!(
        title: "負荷試験の求人 #{index}",
        description: "仕事の内容 #{index}。" * 20,
        location: [ "東京", "大阪", "福岡" ][index % 3],
        occupation: [ "人事", "開発", "営業" ][index % 3],
        employment_type: JobPosting::EMPLOYMENT_TYPES[index % JobPosting::EMPLOYMENT_TYPES.size],
        salary_currency: "JPY",
        annual_salary_min: 4_000_000 + (index % 10) * 500_000,
        status: "published"
      )
      created += 1
    end

    "求人を #{created} 件作った。#{summary}"
  end

  def clean
    organization = Organization.find_by(name: ORGANIZATION_NAME)
    return "負荷試験のデータはない" if organization.nil?

    job_postings = organization.job_postings.count
    User.where("email_address LIKE ?", "#{MARKER}%").destroy_all
    organization.job_postings.destroy_all
    organization.destroy

    "求人 #{job_postings} 件と組織を消した"
  end

  def summary
    "求人 #{JobPosting.count} 件 / 応募 #{JobApplication.count} 件 / " \
      "プロフィール #{CandidateProfile.count} 件 / アカウント #{User.count} 件"
  end

  # 測る側から使う。読み取りだけの経路を測るため、公開中の求人を 1 件返す。
  def sample_job_posting
    JobPosting.published.first
  end

  private
    def find_or_create_organization
      Organization.find_by(name: ORGANIZATION_NAME) ||
        Organization.create_with_owner!(name: ORGANIZATION_NAME, user: owner)
    end

    def owner
      User.find_by(email_address: "#{MARKER}-owner@example.invalid") ||
        User.create!(email_address: "#{MARKER}-owner@example.invalid", password: PASSWORD).tap(&:confirm)
    end
end
