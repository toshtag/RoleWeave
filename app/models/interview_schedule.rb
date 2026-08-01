# 面接の予定。
#
# 社内の予定として持つ。伝える手段（P9）がないため、応募者へは届かない。
# 方針は docs/decisions/0040-interview-schedule-and-deadline.md を正本とする。
class InterviewSchedule < ApplicationRecord
  STATUSES = %w[scheduled cancelled].freeze

  LOCATION_MAX_LENGTH = 500
  NOTE_MAX_LENGTH = 2_000
  MAX_DURATION_MINUTES = 8 * 60

  belongs_to :job_application
  belongs_to :created_by, class_name: "User", optional: true

  attr_readonly :job_application_id, :created_by_id

  validates :starts_at, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :duration_minutes,
            numericality: { only_integer: true, greater_than: 0,
                            less_than_or_equal_to: MAX_DURATION_MINUTES },
            allow_nil: true
  validates :location, length: { maximum: LOCATION_MAX_LENGTH }, allow_blank: true
  validates :note, length: { maximum: NOTE_MAX_LENGTH }, allow_blank: true

  # 過ぎた日時の予定は、予定ではない。作成の時点でだけ確かめる。
  validate :starts_at_is_in_the_future, on: :create

  scope :upcoming, -> { order(:starts_at, :id) }

# 予定の作成と取消も、その応募に起きたことである。
# 応募の記録（ADR 0037）と同じ表へ残す。
after_create :record_scheduled
after_update :record_cancelled, if: :saved_change_to_status?

  def scheduled?
    status == "scheduled"
  end

  # 取り消す。記録は残し、状態だけを変える。
  def cancel
    return false unless scheduled?

    update(status: "cancelled")
  end

private
  def record_scheduled
    job_application.record_interview_event("interview_scheduled", changed_by: created_by)
  end

  def record_cancelled
    return unless status == "cancelled"

    job_application.record_interview_event("interview_cancelled", changed_by: created_by)
  end

  def starts_at_is_in_the_future
      return if starts_at.blank?
      return if starts_at > Time.current

      errors.add(:starts_at, :in_the_past)
    end
end
