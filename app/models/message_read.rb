# メッセージを読んだ記録。
#
# 会話ごとの「最後に読んだ時刻」ではなく、メッセージごとに行を持つ。
# 詳細は docs/decisions/0041-application-conversation.md を参照する。
class MessageRead < ApplicationRecord
  belongs_to :message
  belongs_to :user

  attr_readonly :message_id, :user_id

  # 同じ人が同じメッセージを二重に読んだ記録は持たない。
  validates :message_id, uniqueness: { scope: :user_id }
end
