# 応募と取消の記録。
#
# 応募そのものはプロフィールの削除で消える（ADR 0034）。
# 「応募があった」という事実まで消えると、企業側は何が起きたのかを追えない。
# 方針は docs/decisions/0037-job-application-events-and-notification.md を正本とする。
class JobApplicationEvent < ApplicationRecord
  # 取り得る出来事。値をここで閉じる。
  KINDS = %w[submitted withdrawn].freeze

  belongs_to :job_application, optional: true
  belongs_to :organization
  belongs_to :job_posting, optional: true

  # 記録した内容は後から変えない。書き換えられると、履歴が別の応募の話になる。
  attr_readonly :job_application_id, :organization_id, :job_posting_id, :kind,
                :job_posting_title, :candidate_display_name

  validates :kind, inclusion: { in: KINDS }
  validates :job_posting_title, presence: true
  validates :candidate_display_name, presence: true

  scope :recent, -> { order(created_at: :desc, id: :desc) }
end
