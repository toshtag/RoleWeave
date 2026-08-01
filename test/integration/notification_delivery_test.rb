require "test_helper"

# 配信に失敗した通知の一覧と再送の契約を検証する。
#
# 検証対象は、誰が見られるかと、再送で何が起きるかである。
class NotificationDeliveryTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  PASSWORD = "correct horse battery".freeze

  setup do
    candidate = User.create!(email_address: "candidate@example.com", password: PASSWORD).tap(&:confirm)
    candidate_profile = candidate.create_candidate_profile!(display_name: "山田 太郎")

    @owner = User.create!(email_address: "owner@example.com", password: PASSWORD).tap(&:confirm)
    organization = Organization.create_with_owner!(name: "サンプル株式会社", user: @owner)
    job_posting = organization.job_postings.create!(
      title: "サンプルの求人", description: "仕事の内容", status: "published"
    )
    job_application = candidate_profile.job_applications.create!(job_posting: job_posting)

    @notification = Notification.create!(
      user: @owner, job_application: job_application, kind: "stage_changed"
    )
    @notification.record_email_failure!(Net::SMTPServerBusy.new("接続できない"))

    @operator = User.create!(email_address: "operator@example.com", password: PASSWORD).tap(&:confirm)
    @operator.update!(operator: true)
  end

  test "運営者が失敗した通知の一覧を見られる" do
    sign_in_as(@operator)

    get operator_notification_deliveries_path(locale: :ja)

    assert_response :success
    assert_select "main", text: /接続できない/
  end

  test "運営者でない利用者は一覧を見られない" do
    # 403 と分けると、運営者の経路が存在することだけが分かる。
    sign_in_as(@owner)

    get operator_notification_deliveries_path(locale: :ja)

    assert_response :not_found
  end

  test "未ログインでは一覧を見られない" do
    get operator_notification_deliveries_path(locale: :ja)

    assert_redirected_to new_session_path(locale: :ja)
  end

  test "運営者が再送でき、通知は増えない" do
    sign_in_as(@operator)

    assert_no_difference -> { Notification.count } do
      assert_enqueued_jobs 1, only: NotificationEmailJob do
        patch operator_notification_delivery_path(locale: :ja, id: @notification)
      end
    end

    assert_equal "pending", @notification.reload.email_status
  end

  test "再送したものが成功すると delivered になる" do
    sign_in_as(@operator)

    perform_enqueued_jobs do
      patch operator_notification_delivery_path(locale: :ja, id: @notification)
    end

    assert_equal "delivered", @notification.reload.email_status
  end

  test "失敗していない通知は再送の対象にならない" do
    delivered = Notification.create!(
      user: @owner, job_application: @notification.job_application, kind: "stage_changed"
    )
    delivered.record_email_delivered!
    sign_in_as(@operator)

    patch operator_notification_delivery_path(locale: :ja, id: delivered)

    assert_response :not_found
  end

  test "失敗の内容は運営者以外に見えない" do
    sign_in_as(@owner)

    get notifications_path(locale: :ja)

    assert_response :success
    assert_no_match(/接続できない/, response.body)
  end

  test "一覧を日本語と英語で表示する" do
    sign_in_as(@operator)

    I18n.available_locales.each do |locale|
      get operator_notification_deliveries_path(locale: locale)

      assert_response :success
      assert_select "main h1", text: I18n.t("operator.notification_deliveries.index.title", locale: locale)
    end
  end

  private
    def sign_in_as(user)
      post session_path(locale: :ja), params: { email_address: user.email_address, password: PASSWORD }
    end
end
