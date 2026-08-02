# 配信の結果。
#
# 失敗しても業務処理は巻き戻さない。何が起きたかはここに残す。
# 方針は docs/decisions/0057-webhooks.md を正本とする。
class WebhookDelivery < ApplicationRecord
  STATUSES = %w[pending delivered failed].freeze

  # 失敗の種別。`error` の列はこの値だけを持つ。
  #
  # 例外のメッセージをそのまま残さない。残すと、接続を拒まれたのか、
  # 名前が引けないのか、応答が返ったのかの違いが画面に出る。
  # その違いは、内部のどこに何が居るかを教える（ADR 0060）。
  FAILURE_REASONS = %w[blocked_destination internal_address unresolvable
                       invalid_scheme timeout connection_failed http_error].freeze

  belongs_to :webhook

  validates :event_kind, inclusion: { in: Webhook::EVENT_KINDS }
  validates :status, inclusion: { in: STATUSES }

  scope :recent, -> { order(created_at: :desc, id: :desc) }
  scope :failed, -> { where(status: "failed") }

  def record_delivered!(response_code)
    update_columns(status: "delivered", response_code: response_code,
                   delivered_at: Time.current, error: nil, attempts: attempts + 1)
  end

  # 失敗を種別として残す。知らない値は、種別を足し忘れた場合に備えて丸める。
  def record_failure!(reason, response_code: nil)
    reason = reason.to_s
    reason = "connection_failed" unless FAILURE_REASONS.include?(reason)

    update_columns(status: "failed", response_code: response_code,
                   attempts: attempts + 1, error: reason)
  end
end
