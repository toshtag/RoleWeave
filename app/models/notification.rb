# 利用者へのアプリ内通知。
#
# 設定によらず作る。設定はメールの送信だけを止める。
# アプリの中の記録まで止めると、後から見返す手段がなくなる。
# 方針は docs/decisions/0042-notifications.md を正本とする。
class Notification < ApplicationRecord
  KINDS = %w[message_received stage_changed].freeze

  belongs_to :user
  belongs_to :job_application, optional: true
  belongs_to :message, optional: true

  attr_readonly :user_id, :job_application_id, :message_id, :kind

  validates :kind, inclusion: { in: KINDS }

  scope :recent, -> { order(created_at: :desc, id: :desc) }
  scope :unread, -> { where(read_at: nil) }

  def read?
    read_at.present?
  end

  # 一覧を開いた時点で既読にする。
  def self.mark_all_read(user)
    unread.where(user: user).update_all(read_at: Time.current)
  end
end
