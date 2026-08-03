# net/http は Rails が読み込まない。使う側で宣言する。
# 宣言しないと、たまたま同じ環境で読み込まれている別の gem に依存することになり、
# その gem を外した瞬間に、ここが NameError で落ちる。
require "net/http"

# Webhook を送り、結果を記録するジョブ。
#
# 送るのは外である。失敗しても業務処理は巻き戻さない。
# 例外は握り潰さない。握り潰すと、ジョブの再試行が働かなくなる（ADR 0043 と同じ）。
#
# 送り先の判定は WebhookDestination が持つ。**判定した IP へ接続する。**
# 方針は docs/decisions/0057-webhooks.md と
# docs/decisions/0060-webhook-destination-restriction.md を正本とする。
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
      delivery.record_failure!("http_error", response_code: response.code.to_i)

      raise DeliveryFailed, "配信に失敗した: HTTP #{response.code}"
    end
  rescue DeliveryFailed
    raise
  rescue WebhookDestination::Blocked => error
    # 送り先が判定を通らなかった。相手の不調ではなく、宛先そのものの問題である。
    delivery.record_failure!(error.message)

    raise
  rescue Timeout::Error
    delivery.record_failure!("timeout")

    raise
  rescue StandardError
    # 例外の内容は残さない。接続できないのか、拒まれたのか、名前が引けないのかの違いが、
    # そのまま内部のどこに何が居るかを教える手がかりになる。
    delivery.record_failure!("connection_failed")

    raise
  end

  class DeliveryFailed < StandardError; end

  private
    def post(webhook, body)
      destination = WebhookDestination.new(webhook.url)
      # 名前の解決は 1 度だけ行う。接続の直前にもう一度引くと、
      # その間に応答を変えられる（DNS rebinding）。
      address = destination.connect_address
      uri = destination.uri

      Net::HTTP.start(uri.hostname, uri.port, **connection_options(uri, address)) do |http|
        http.request(build_request(uri, webhook, body))
      end
    end

    # ホスト名は Host header と TLS の証明書の照合のために残し、
    # 実際に繋ぐ先だけを判定した IP へ差し替える。
    # 明示して許した宛先（address が nil）では、名前のまま繋ぐ。
    #
    # リダイレクトは追わない。Net::HTTP は既定で追わず、ここでも追わせない。
    # 追うと、判定を通った URL から内部の宛先へ飛べる。
    def connection_options(uri, address)
      {
        ipaddr: address,
        use_ssl: uri.scheme == "https",
        open_timeout: TIMEOUT_SECONDS,
        read_timeout: TIMEOUT_SECONDS,
        # 接続が切れたときに黙って送り直さない。同じ出来事が 2 回届く。
        max_retries: 0
      }
    end

    def build_request(uri, webhook, body)
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      # 送り先が本物であることを確かめられるようにする。
      request["X-RoleWeave-Signature"] = webhook.signature_for(body)
      request.body = body

      request
    end
end
