# Webhook を送り、結果を記録するジョブ。
#
# 送るのは外である。失敗しても業務処理は巻き戻さない。
# 例外は握り潰さない。握り潰すと、ジョブの再試行が働かなくなる（ADR 0043 と同じ）。
# 方針は docs/decisions/0057-webhooks.md を正本とする。
class WebhookDeliveryJob < ApplicationJob
  queue_as :default

  # 応答を待つ上限。相手が遅いだけで、こちらのジョブが埋まらないようにする。
  TIMEOUT_SECONDS = 5

  def perform(delivery, payload)
    webhook = delivery.webhook
    body = payload.to_json

    response = post(webhook, body)

    if response.is_a?(Net::HTTPSuccess)
      delivery.record_delivered!(response.code.to_i)
    else
      delivery.record_failure!("HTTP #{response.code}", response_code: response.code.to_i)

      raise DeliveryFailed, "配信に失敗した: HTTP #{response.code}"
    end
  rescue DeliveryFailed
    raise
  rescue StandardError => error
    delivery.record_failure!(error)

    raise
  end

  class DeliveryFailed < StandardError; end

  private
    def post(webhook, body)
      uri = URI.parse(webhook.url)
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      # 送り先が本物であることを確かめられるようにする。
      request["X-RoleWeave-Signature"] = webhook.signature_for(body)
      request.body = body

      Net::HTTP.start(uri.hostname, uri.port,
                      use_ssl: uri.scheme == "https",
                      open_timeout: TIMEOUT_SECONDS,
                      read_timeout: TIMEOUT_SECONDS) do |http|
        http.request(request)
      end
    end
end
