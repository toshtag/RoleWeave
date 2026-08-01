# 利用者へのアプリ内通知。
#
# 設定によらず作る。設定はメールの送信だけを止める。
# アプリの中の記録まで止めると、後から見返す手段がなくなる。
# 方針は docs/decisions/0042-notifications.md を正本とする。
class Notification < ApplicationRecord
  KINDS = %w[message_received stage_changed].freeze

  # メールの配信の状態。
  # skipped は「設定により送らない」であり、失敗ではない。
  EMAIL_STATUSES = %w[skipped pending delivered failed].freeze

  belongs_to :user
  belongs_to :job_application, optional: true
  belongs_to :message, optional: true

  attr_readonly :user_id, :job_application_id, :message_id, :kind

  validates :kind, inclusion: { in: KINDS }
  validates :email_status, inclusion: { in: EMAIL_STATUSES }

  scope :recent, -> { order(created_at: :desc, id: :desc) }
  scope :unread, -> { where(read_at: nil) }
  scope :email_failed, -> { where(email_status: "failed") }

  def read?
    read_at.present?
  end

  # 送信に成功した。
  def record_email_delivered!
  update_columns(email_status: "delivered", email_delivered_at: Time.current, email_error: nil)
  end

  # 送信に失敗した。内容をそのまま残す。運営者が原因を追えるようにする。
  def record_email_failure!(error)
  update_columns(
    email_status: "failed",
    email_attempts: email_attempts + 1,
    email_error: "#{error.class}: #{error.message}"
  )
  end

  def email_failed?
  email_status == "failed"
  end

  # 一覧を開いた時点で既読にする。
  def self.mark_all_read(user)
    unread.where(user: user).update_all(read_at: Time.current)
  end
end
