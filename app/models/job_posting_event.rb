# 求人の公開状態の変更の記録。
#
# 「いつからその求人が公開されていたか」は後から復元できない。
# 対象の求人と組織が削除されても記録は残す。
# 方針は docs/decisions/0018-job-posting-status-history.md を正本とする。
class JobPostingEvent < ApplicationRecord
  belongs_to :job_posting, optional: true
  belongs_to :organization, optional: true
  belongs_to :changed_by, class_name: "User", optional: true

  # 記録した内容は後から変えない。書き換えられると、履歴が別の求人の話になる。
  attr_readonly :job_posting_id, :organization_id, :from_status, :to_status, :job_posting_title

  validates :to_status, inclusion: { in: JobPosting::STATUSES }
  validates :from_status, inclusion: { in: JobPosting::STATUSES }, allow_nil: true
  validates :job_posting_title, presence: true

  scope :recent, -> { order(created_at: :desc, id: :desc) }

  def created?
    from_status.nil?
  end
end
