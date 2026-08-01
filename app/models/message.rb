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

  def read_by?(user)
    message_reads.exists?(user_id: user.id)
  end
end
