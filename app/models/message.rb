# 会話の 1 通。
#
# 方針は docs/decisions/0041-application-conversation.md を正本とする。
class Message < ApplicationRecord
  BODY_MAX_LENGTH = 5_000

  belongs_to :conversation
  # 送信者を削除してもメッセージは残す。相手から見て、やり取りが消えない。
  belongs_to :sender, class_name: "User", optional: true

  # 送った内容は後から変えない。相手が読んだものと食い違う。
  attr_readonly :conversation_id, :sender_id, :body

  has_many :message_reads, dependent: :destroy

  validates :body, presence: true, length: { maximum: BODY_MAX_LENGTH }

  scope :chronological, -> { order(:created_at, :id) }

  # 通知はトランザクションが閉じた後に積む。
  # 同じトランザクションの中で送ると、メールが送れないだけでメッセージが失敗する。
  # 詳細は docs/decisions/0042-notifications.md を参照する。
  after_commit :notify_recipients, on: :create

  def read_by?(user)
    message_reads.exists?(user_id: user.id)
  end

  private
    # 宛先は会話の参加者から自分を除いたもの。
    def notify_recipients
      recipients.each do |recipient|
        notification = Notification.create!(
          user: recipient, job_application: conversation.job_application,
          message: self, kind: "message_received"
        )

        next unless recipient.email_notifications?

        NotificationMailer.message_received(notification, locale: I18n.locale).deliver_later
      end
    end

    def recipients
      job_application = conversation.job_application
      users = [ job_application.candidate_profile.user ] +
              job_application.job_posting.organization.users.to_a

      users.uniq.reject { |user| user.id == sender_id }
    end
end
