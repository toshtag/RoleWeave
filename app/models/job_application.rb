# 求職者から求人への応募。
#
# モデル名を `Application` にしない。Rails は `RoleWeave::Application` を持ち、
# 名前の解決が読み手にとって曖昧になる。
# 方針は docs/decisions/0034-job-application.md を正本とする。
class JobApplication < ApplicationRecord
  # 応募そのものの状態。選考がどこまで進んだかは stage が持つ。
  STATUSES = %w[submitted withdrawn].freeze

  # 選考ステージ。
  #
  # 「応募が生きているか」（status）とは別の軸である。
  # 詳細は docs/decisions/0038-selection-stage.md を正本とする。
  STAGES = %w[screening interviewing offered hired rejected declined].freeze

  # 進める先を状態ごとに定める。任意の状態へは飛べない。
  # hired / rejected / declined は終わりとし、そこからは動かせない。
  STAGE_TRANSITIONS = {
    "screening" => %w[interviewing rejected],
    "interviewing" => %w[offered rejected],
    "offered" => %w[hired declined rejected],
    "hired" => [],
    "rejected" => [],
    "declined" => []
  }.freeze

  # 確定は管理者だけができる。採否は、その後の関係を決める操作である。
  # 求人の審査（ADR 0017）で、申請と承認を分けたのと同じ理由による。
  OWNER_ONLY_STAGES = %w[offered hired rejected declined].freeze

  belongs_to :candidate_profile
  belongs_to :job_posting

  # 選考の担当者。組織の所属者の中から選ぶ。
  belongs_to :assignee, class_name: "User", optional: true

  # 評価とコメント。応募を消したら残さない。
  has_many :application_reviews, dependent: :destroy

  # 面接の予定。応募を消したら残さない。
  has_many :interview_schedules, dependent: :destroy

  # 会話。応募を消したら、やり取りも残さない。
  has_one :conversation, dependent: :destroy

  # 応募先も応募元も、作成した後で変えられないようにする。
  # 変えられると、応募時点の写しと結び付きが食い違う。
  attr_readonly :candidate_profile_id, :job_posting_id

  validates :status, inclusion: { in: STATUSES }
  # 同じ求職者が同じ求人へ 2 回応募することを拒否する。
  validates :candidate_profile_id, uniqueness: { scope: :job_posting_id }

  validates :stage, inclusion: { in: STAGES }

  validate :job_posting_is_published, on: :create
  # 担当者はその組織の所属者に限る。外部の利用者を担当にできると、
  # 応募が組織の外から扱われる状態になる。
  validate :assignee_belongs_to_organization
  # 期限は、これから決めるためのものである。過ぎた日付は期限にならない。
  validate :decide_by_is_not_in_the_past, if: :will_save_change_to_decide_by?

  # 応募時点の写しを、作成時に固定する。
  # Controller ではなくモデルへ置く。応募を作る経路が増えても、写し忘れが起こらない。
  before_validation :capture_snapshots, on: :create

  # 応募と取消を記録へ残す。応募そのものはプロフィールの削除で消えるため、
  # 企業側に残る記録はこの表が持つ。
  # 詳細は docs/decisions/0037-job-application-events-and-notification.md を参照する。
  after_create :record_submitted
  after_update :record_withdrawn, if: :saved_change_to_status?
  after_update :record_stage_changed, if: :saved_change_to_stage?
  # 選考の状況の変化は応募者へだけ知らせる。
  # 企業側は自分たちで動かしているため、知らせる意味がない。
  after_commit :notify_candidate_of_stage_change, if: :saved_change_to_stage?

  # 通知はトランザクションが閉じた後に積む。
  #
  # 同じトランザクションの中で送ると、メールが送れないだけで応募が失敗する。
  # 送るのは外（SMTP）であり、こちらの都合では成功を保証できない。
  after_commit :notify_organization, on: :create

  # 外部への配信。失敗しても業務処理は巻き戻さない。
  # 詳細は docs/decisions/0057-webhooks.md を参照する。
  after_commit :deliver_webhooks_for_creation, on: :create
  after_commit :deliver_webhooks_for_stage_change, if: :saved_change_to_stage?

  scope :recent, -> { order(created_at: :desc, id: :desc) }
  scope :submitted, -> { where(status: "submitted") }
  # 期限を過ぎた応募。放置に気付けるようにする。
  scope :overdue, -> { submitted.where(decide_by: ...Date.current) }

  def submitted?
    status == "submitted"
  end

  # 期限を過ぎているか。画面で印を付けるために使う。
  def overdue?
    submitted? && decide_by.present? && decide_by < Date.current
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

  # そのステージへ進められるか。
  #
  # 取り消された応募は動かせない。応募者がもう選考を望んでいない。
  def can_move_to?(next_stage)
    submitted? && STAGE_TRANSITIONS.fetch(stage, []).include?(next_stage)
  end

  # 確定（内定・採用・不採用・辞退）は管理者だけができる。
  def self.owner_only_stage?(next_stage)
    OWNER_ONLY_STAGES.include?(next_stage)
  end

  # 選考を進める。変更した利用者を記録へ残す。
  def move_to(next_stage, changed_by:)
    return false unless can_move_to?(next_stage)

    self.stage_changed_by = changed_by

    update(stage: next_stage)
  end

  # 記録のためだけに使い、保存はしない。
  attr_accessor :stage_changed_by

# 面接の予定の記録。予定の側から呼ぶ。
# 記録の作り方を 1 か所に保つため、応募が受け持つ。
def record_interview_event(kind, changed_by:)
  record_event(kind, changed_by: changed_by)
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

    def record_stage_changed
      from_stage, to_stage = saved_change_to_stage

      record_event("stage_changed", from_stage: from_stage, to_stage: to_stage,
                                    changed_by: stage_changed_by)
    end

    # 参照が消えた後も読めるように、題名と表示名を写して持つ。
    def record_event(kind, from_stage: nil, to_stage: nil, changed_by: nil)
      JobApplicationEvent.create!(
        job_application: self,
        organization: job_posting.organization,
        job_posting: job_posting,
        kind: kind,
        job_posting_title: job_posting_snapshot["title"],
        candidate_display_name: candidate_profile_snapshot["display_name"],
        from_stage: from_stage,
        to_stage: to_stage,
        changed_by: changed_by
      )
    end

    def notify_candidate_of_stage_change
      candidate = candidate_profile.user

      notification = Notification.create!(
    user: candidate, job_application: self, kind: "stage_changed"
      )

      unless candidate.email_notifications?
        notification.update_column(:email_status, "skipped")
        return
      end

      NotificationEmailJob.perform_later(notification, locale: I18n.locale)
    end

    def deliver_webhooks_for_creation
      deliver_webhooks("job_application_created")
    end

    def deliver_webhooks_for_stage_change
      deliver_webhooks("job_application_stage_changed", extra: { stage: stage })
    end

    # 送るのは識別子と種類だけとする。氏名も本文も送らない。
    # 送り先はこちらの管理下になく、公開範囲（ADR 0030）が効かない。
    def deliver_webhooks(event_kind, extra: {})
      organization = job_posting.organization

      Webhook.for_event(organization, event_kind).each do |webhook|
    delivery = webhook.webhook_deliveries.create!(event_kind: event_kind)

    WebhookDeliveryJob.perform_later(delivery, {
      event: event_kind,
      occurred_at: Time.current,
      organization_id: organization.id,
      job_posting_id: job_posting_id,
      job_application_id: id
    }.merge(extra))
      end
    end

    # 宛先は組織の管理者とする。一般の所属者へは送らない。
    def notify_organization
      job_posting.organization.memberships.where(role: "owner").includes(:user).find_each do |membership|
        OrganizationMailer.job_application(self, to: membership.user.email_address,
                                                 locale: I18n.locale).deliver_later
      end
    end

    def decide_by_is_not_in_the_past
      return if decide_by.nil?
      return if decide_by >= Date.current

      errors.add(:decide_by, :in_the_past)
    end

    def assignee_belongs_to_organization
      return if assignee.nil? || job_posting.nil?
      return if job_posting.organization.memberships.exists?(user_id: assignee_id)

      errors.add(:assignee, :not_a_member)
    end

    # 応募できるのは公開中の求人だけとする。
    # 下書きや停止中の求人へ応募できると、まだ募集していない仕事へ応募が届く。
    def job_posting_is_published
      return if job_posting.nil?
      return if job_posting.status == "published"

      errors.add(:job_posting, :not_published)
    end
end
