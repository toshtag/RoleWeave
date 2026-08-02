require "test_helper"

# 外部への配信の契約を検証する。
#
# 検証対象は、何を送るかと、失敗が業務処理へ波及しないことである。
class WebhookTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  PASSWORD = "correct horse battery".freeze

  setup do
    @owner = User.create!(email_address: "owner@example.com", password: PASSWORD).tap(&:confirm)
    @organization = Organization.create_with_owner!(name: "サンプル株式会社", user: @owner)
    @member = User.create!(email_address: "member@example.com", password: PASSWORD).tap(&:confirm)
    Membership.create!(organization: @organization, user: @member, role: "member")

    @job_posting = @organization.job_postings.create!(
      title: "サンプルの求人", description: "仕事の内容", status: "published"
    )

    candidate = User.create!(email_address: "candidate@example.com", password: PASSWORD).tap(&:confirm)
    @profile = candidate.create_candidate_profile!(display_name: "山田 太郎")
  end

  test "管理者が配信先を登録でき、秘密は登録時にだけ出る" do
    sign_in_as(@owner)

    post webhooks_path, params: { webhook: { url: "https://example.invalid/hook",
                                             event_kinds: [ "job_application_created" ] } }

    webhook = Webhook.sole

    assert_equal [ "job_application_created" ], webhook.event_kinds
    assert_match(/#{webhook.secret}/, flash[:notice])

    # 遷移先で 1 度だけ出る。
    follow_redirect!

    assert_match(/#{webhook.secret}/, response.body)

    # もう一度開くと、出ない。
    get webhooks_path

    assert_no_match(/#{webhook.secret}/, response.body)
  end

  test "一般の所属者は配信先を扱えない" do
    sign_in_as(@member)

    get webhooks_path

    assert_response :not_found
  end

  test "http と https 以外を拒否する" do
    assert_not @organization.webhooks.build(url: "file:///etc/passwd").valid?
    assert_not @organization.webhooks.build(url: "ftp://example.invalid").valid?
    assert_predicate @organization.webhooks.build(url: "https://example.invalid/hook"), :valid?
  end

  test "内部のアドレスを登録できない" do
    # 判定は WebhookDestination が持つ。ここでは経路が判定を通ることだけを見る。
    sign_in_as(@owner)

    post webhooks_path, params: { webhook: { url: "http://169.254.169.254/latest/",
                                             event_kinds: [ "job_application_created" ] } }

    assert_equal 0, Webhook.count
    assert_match(/#{I18n.t("activerecord.errors.models.webhook.attributes.url.internal_address")}/,
                 flash[:alert])
  end

  test "知らない種類を拒否する" do
    assert_not @organization.webhooks.build(url: "https://example.invalid/hook",
                                            event_kinds: [ "unknown" ]).valid?
  end

  test "応募があると配信が積まれる" do
    webhook(event_kinds: [ "job_application_created" ])

    assert_difference -> { WebhookDelivery.count }, 1 do
      assert_enqueued_jobs 1, only: WebhookDeliveryJob do
        @profile.job_applications.create!(job_posting: @job_posting)
      end
    end
  end

  test "選んでいない種類では配信されない" do
    webhook(event_kinds: [ "job_application_stage_changed" ])

    assert_no_difference -> { WebhookDelivery.count } do
      @profile.job_applications.create!(job_posting: @job_posting)
    end
  end

  test "選考の段階が変わると配信が積まれる" do
    webhook(event_kinds: [ "job_application_stage_changed" ])
    application = @profile.job_applications.create!(job_posting: @job_posting)

    assert_difference -> { WebhookDelivery.count }, 1 do
      application.move_to("interviewing", changed_by: @owner)
    end
  end

  test "無効にした配信先へは送らない" do
    webhook(enabled: false)

    assert_no_difference -> { WebhookDelivery.count } do
      @profile.job_applications.create!(job_posting: @job_posting)
    end
  end

  test "送る本文に個人情報が含まれない" do
    # 送り先はこちらの管理下になく、公開範囲の設定が効かない。
    hook = webhook
    application = @profile.job_applications.create!(job_posting: @job_posting)
    payload = enqueued_jobs.find { |job| job["job_class"] == "WebhookDeliveryJob" }["arguments"].last

    body = payload.to_json

    assert_no_match(/山田 太郎/, body)
    assert_no_match(/candidate@example\.com/, body)
    assert_match(/#{application.id}/, body)
    assert_equal hook.event_kinds.first, payload["event"]
  end

  test "配信の失敗で応募は巻き戻らない" do
    webhook
    original = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = FailingQueueAdapter.new

    assert_raises(IOError) do
      @profile.job_applications.create!(job_posting: @job_posting)
    end

    assert_equal 1, JobApplication.count
  ensure
    ActiveJob::Base.queue_adapter = original
  end

  test "配信の結果が履歴として残る" do
    hook = webhook
    delivery = hook.webhook_deliveries.create!(event_kind: "job_application_created")

    delivery.record_failure!("connection_failed")

    assert_equal "failed", delivery.reload.status
    assert_equal 1, delivery.attempts
    assert_equal "connection_failed", delivery.error

    delivery.record_delivered!(200)

    assert_equal "delivered", delivery.reload.status
    assert_equal 200, delivery.response_code
    assert_nil delivery.error
  end

  test "署名を作れる" do
    hook = webhook

    assert_equal OpenSSL::HMAC.hexdigest("SHA256", hook.secret, "{}"), hook.signature_for("{}")
  end

  test "配信先を削除すると履歴も消える" do
    hook = webhook
    hook.webhook_deliveries.create!(event_kind: "job_application_created")

    assert_difference -> { WebhookDelivery.count }, -1 do
      hook.destroy
    end
  end

  test "配信の画面を日本語と英語で表示する" do
    webhook
    sign_in_as(@owner)

    I18n.available_locales.each do |locale|
      get organization_webhooks_path(locale: locale, organization_id: @organization)

      assert_response :success
      assert_select "main h1", text: I18n.t("organizations.webhooks.index.title", locale: locale)
    end
  end

  class FailingQueueAdapter
    def enqueue(*) = raise(IOError, "積めない")
    def enqueue_at(*) = raise(IOError, "積めない")
  end

  private
    def sign_in_as(user)
      post session_path(locale: :ja), params: { email_address: user.email_address, password: PASSWORD }
    end

    def webhooks_path
      organization_webhooks_path(locale: :ja, organization_id: @organization)
    end

    def webhook(event_kinds: [ "job_application_created" ], enabled: true)
      @organization.webhooks.create!(url: "https://example.invalid/hook",
                                     event_kinds: event_kinds, enabled: enabled)
    end
end
