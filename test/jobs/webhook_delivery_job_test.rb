require "test_helper"

# 応答の種別を Net:: の定数で作るため、ここでも宣言する。
# ジョブの読み込みより先にこれらへ触れる test があり、
# ジョブ側の require だけでは実行順に依存する。
require "net/http"

# 外部への配信の契約を検証する。
#
# 検証対象は、内部を指す宛先へ繋がないことと、
# 失敗の内容が種別までにとどまることである。
class WebhookDeliveryJobTest < ActiveJob::TestCase
  PASSWORD = "correct horse battery".freeze

  setup do
    owner = User.create!(email_address: "owner@example.com", password: PASSWORD).tap(&:confirm)
    @organization = Organization.create_with_owner!(name: "サンプル株式会社", user: owner)
  end

  test "解決できない宛先は unresolvable として残る" do
    delivery = delivery_for("https://example.invalid/hook")

    assert_raises(WebhookDestination::Blocked) do
      WebhookDeliveryJob.perform_now(delivery, { event: "job_application_created" })
    end

    assert_equal "failed", delivery.reload.status
    assert_equal "unresolvable", delivery.error
    assert_equal 1, delivery.attempts
  end

  test "名前が内部の IP へ解決される宛先は internal_address として残る" do
    # 登録の時点では名前を解決しない。配信の時点で気付く。
    delivery = delivery_for("http://localhost/hook")

    assert_raises(WebhookDestination::Blocked) do
      WebhookDeliveryJob.perform_now(delivery, { event: "job_application_created" })
    end

    assert_equal "internal_address", delivery.reload.error
  end

  test "失敗の内容に例外のメッセージが残らない" do
    delivery = delivery_for("https://example.invalid/hook")

    assert_raises(WebhookDestination::Blocked) do
      WebhookDeliveryJob.perform_now(delivery, { event: "job_application_created" })
    end

    assert_includes WebhookDelivery::FAILURE_REASONS, delivery.reload.error
  end

  test "知らない種別は connection_failed へ丸める" do
    delivery = delivery_for("https://example.invalid/hook")

    delivery.record_failure!("Errno::ECONNREFUSED: Connection refused - 10.0.0.5:8080")

    assert_equal "connection_failed", delivery.reload.error
  end

  test "配信は判定した IP へ繋ぎ、ホスト名は残す" do
    delivery = delivery_for("http://93.184.216.34/hook")

    calls = without_sending do
      WebhookDeliveryJob.perform_now(delivery, { event: "job_application_created" })
    end

    host, port, options = calls.sole

    assert_equal "93.184.216.34", host
    assert_equal 80, port
    assert_equal "93.184.216.34", options[:ipaddr]
    assert_not options[:use_ssl]
    # 接続が切れたときに黙って送り直さない。同じ出来事が 2 回届く。
    assert_equal 0, options[:max_retries]
  end

  test "配信に成功すると応答コードが残る" do
    delivery = delivery_for("http://93.184.216.34/hook")

    without_sending do
      WebhookDeliveryJob.perform_now(delivery, { event: "job_application_created" })
    end

    assert_equal "delivered", delivery.reload.status
    assert_equal 200, delivery.response_code
  end

  test "送り先が異常な応答を返すと http_error として残る" do
    delivery = delivery_for("http://93.184.216.34/hook")

    without_sending(Net::HTTPForbidden.new("1.1", "403", "Forbidden")) do
      assert_raises(WebhookDeliveryJob::DeliveryFailed) do
        WebhookDeliveryJob.perform_now(delivery, { event: "job_application_created" })
      end
    end

    assert_equal "http_error", delivery.reload.error
    assert_equal 403, delivery.response_code
  end

  test "接続の失敗は connection_failed として残り、例外の内容は残らない" do
    # 「接続を拒まれた」と「経路がない」の違いは、内部に何が居るかを教える。
    delivery = delivery_for("http://93.184.216.34/hook")

    without_sending(Errno::ECONNREFUSED.new("connect(2) for 10.0.0.5:8080")) do
      assert_raises(Errno::ECONNREFUSED) do
        WebhookDeliveryJob.perform_now(delivery, { event: "job_application_created" })
      end
    end

    assert_equal "connection_failed", delivery.reload.error
    assert_nil delivery.response_code
  end

  test "応答を待てない場合は timeout として残る" do
    delivery = delivery_for("http://93.184.216.34/hook")

    without_sending(Net::OpenTimeout.new) do
      assert_raises(Net::OpenTimeout) do
        WebhookDeliveryJob.perform_now(delivery, { event: "job_application_created" })
      end
    end

    assert_equal "timeout", delivery.reload.error
  end

  test "リダイレクトを追わない" do
    # 追うと、判定を通った URL から内部の宛先へ飛べる。
    delivery = delivery_for("http://93.184.216.34/hook")

    calls = without_sending(Net::HTTPFound.new("1.1", "302", "Found")) do
      assert_raises(WebhookDeliveryJob::DeliveryFailed) do
        WebhookDeliveryJob.perform_now(delivery, { event: "job_application_created" })
      end
    end

    assert_equal 1, calls.size
    assert_equal "http_error", delivery.reload.error
    assert_equal 302, delivery.response_code
  end

  # 応答を返すだけの相手。実際の送信は行わない。
  # 例外を渡すと、その例外を投げる相手になる。
  class FakeHttp
    def initialize(response) = @response = response

    def request(_request)
      raise @response if @response.is_a?(Exception)

      @response
    end
  end

  private
    def delivery_for(url)
      webhook = @organization.webhooks.create!(url: url, event_kinds: [ "job_application_created" ])

      webhook.webhook_deliveries.create!(event_kind: "job_application_created")
    end

    # 送信の入口だけを差し替え、どこへ繋ごうとしたかを記録する。
    # minitest 6 は mock を同梱しないため、ここで直接差し替えて元へ戻す。
    def without_sending(response = Net::HTTPOK.new("1.1", "200", "OK"))
      calls = []
      original = Net::HTTP.method(:start)

      Net::HTTP.define_singleton_method(:start) do |host, port = nil, **options, &block|
        calls << [ host, port, options ]

        block.call(FakeHttp.new(response))
      end

      yield

      calls
    ensure
      Net::HTTP.define_singleton_method(:start, original)
    end
end
