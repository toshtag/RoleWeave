# 求職者から求人への応募。
#
# モデル名を `Application` にしない。Rails は `RoleWeave::Application` を持ち、
# 名前の解決が読み手にとって曖昧になる。
# 方針は docs/decisions/0034-job-application.md を正本とする。
class JobApplication < ApplicationRecord
  # 応募そのものの状態。選考の状態（書類選考、面接など）は P8 で扱う。
  STATUSES = %w[submitted withdrawn].freeze

  belongs_to :candidate_profile
  belongs_to :job_posting

  # 応募先も応募元も、作成した後で変えられないようにする。
  # 変えられると、応募時点の写しと結び付きが食い違う。
  attr_readonly :candidate_profile_id, :job_posting_id

  validates :status, inclusion: { in: STATUSES }
  # 同じ求職者が同じ求人へ 2 回応募することを拒否する。
  validates :candidate_profile_id, uniqueness: { scope: :job_posting_id }

  validate :job_posting_is_published, on: :create

  # 応募時点の写しを、作成時に固定する。
  # Controller ではなくモデルへ置く。応募を作る経路が増えても、写し忘れが起こらない。
  before_validation :capture_snapshots, on: :create

  # 応募と取消を記録へ残す。応募そのものはプロフィールの削除で消えるため、
  # 企業側に残る記録はこの表が持つ。
  # 詳細は docs/decisions/0037-job-application-events-and-notification.md を参照する。
  after_create :record_submitted
  after_update :record_withdrawn, if: :saved_change_to_status?

  # 通知はトランザクションが閉じた後に積む。
  #
  # 同じトランザクションの中で送ると、メールが送れないだけで応募が失敗する。
  # 送るのは外（SMTP）であり、こちらの都合では成功を保証できない。
  after_commit :notify_organization, on: :create

  scope :recent, -> { order(created_at: :desc, id: :desc) }
  scope :submitted, -> { where(status: "submitted") }

  def submitted?
    status == "submitted"
  end

  def withdrawn?
    status == "withdrawn"
  end

  # 取り消す。すでに取り消した応募は、もう一度取り消せない。
  #
  # 記録は残す。消すと、企業側から見て「応募がなかったこと」になる。
  # 詳細は docs/decisions/0035-application-withdrawal.md を参照する。
  def withdraw
    return false unless submitted?

    update(status: "withdrawn")
  end

  private
    def capture_snapshots
      return if candidate_profile.nil? || job_posting.nil?

      self.job_posting_snapshot = ApplicationSnapshot.of_job_posting(job_posting)
      self.candidate_profile_snapshot = ApplicationSnapshot.of_candidate_profile(candidate_profile)
    end

    def record_submitted
      record_event("submitted")
    end

    def record_withdrawn
      record_event("withdrawn") if withdrawn?
    end

    # 参照が消えた後も読めるように、題名と表示名を写して持つ。
    def record_event(kind)
      JobApplicationEvent.create!(
        job_application: self,
        organization: job_posting.organization,
        job_posting: job_posting,
        kind: kind,
        job_posting_title: job_posting_snapshot["title"],
        candidate_display_name: candidate_profile_snapshot["display_name"]
      )
    end

    # 宛先は組織の管理者とする。一般の所属者へは送らない。
    def notify_organization
      job_posting.organization.memberships.where(role: "owner").includes(:user).find_each do |membership|
        OrganizationMailer.job_application(self, to: membership.user.email_address,
                                                 locale: I18n.locale).deliver_later
      end
    end

    # 応募できるのは公開中の求人だけとする。
    # 下書きや停止中の求人へ応募できると、まだ募集していない仕事へ応募が届く。
    def job_posting_is_published
      return if job_posting.nil?
      return if job_posting.status == "published"

      errors.add(:job_posting, :not_published)
    end
end
