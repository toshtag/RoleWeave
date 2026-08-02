# 配信の結果。
#
# 失敗しても業務処理は巻き戻さない。何が起きたかはここに残す。
# 方針は docs/decisions/0057-webhooks.md を正本とする。
class WebhookDelivery < ApplicationRecord
  STATUSES = %w[pending delivered failed].freeze

  belongs_to :webhook

  validates :event_kind, inclusion: { in: Webhook::EVENT_KINDS }
  validates :status, inclusion: { in: STATUSES }

  scope :recent, -> { order(created_at: :desc, id: :desc) }
  scope :failed, -> { where(status: "failed") }

  def record_delivered!(response_code)
    update_columns(status: "delivered", response_code: response_code,
                   delivered_at: Time.current, error: nil, attempts: attempts + 1)
  end

  def record_failure!(error, response_code: nil)
    update_columns(status: "failed", response_code: response_code,
                   attempts: attempts + 1,
                   error: error.is_a?(String) ? error : "#{error.class}: #{error.message}")
  end
end
