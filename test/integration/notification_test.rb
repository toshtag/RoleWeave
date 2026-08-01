require "test_helper"

# 通知の契約を検証する。
#
# 検証対象は、誰に何が作られるか、メールの設定が何を止めるかである。
class NotificationTest < ActionDispatch::IntegrationTest
  # 通知のメールは専用のジョブ（NotificationEmailJob）で送る。
  # 積まれたことは、そのジョブの数で数える。
  include ActiveJob::TestHelper

  PASSWORD = "correct horse battery".freeze

  # 通知を積む処理そのものが失敗する状況を作るための差し替え先。
  class FailingQueueAdapter
    def enqueue(*) = raise(IOError, "送信できない")
    def enqueue_at(*) = raise(IOError, "送信できない")
  end

  setup do
    @candidate = User.create!(email_address: "candidate@example.com", password: PASSWORD).tap(&:confirm)
    @candidate_profile = @candidate.create_candidate_profile!(display_name: "山田 太郎")

    @owner = User.create!(email_address: "owner@example.com", password: PASSWORD).tap(&:confirm)
    @organization = Organization.create_with_owner!(name: "サンプル株式会社", user: @owner)
    @member = User.create!(email_address: "member@example.com", password: PASSWORD).tap(&:confirm)
    Membership.create!(organization: @organization, user: @member, role: "member")

    @job_posting = @organization.job_postings.create!(
      title: "サンプルの求人", description: "仕事の内容", status: "published"
    )
    @job_application = @candidate_profile.job_applications.create!(job_posting: @job_posting)
    @conversation = Conversation.create!(job_application: @job_application)
  end

  test "メッセージを送ると相手に通知が作られる" do
    # 組織側の宛先は所属者すべてとする。
    assert_difference -> { Notification.count }, 2 do
      @conversation.messages.create!(sender: @candidate, body: "応募者からの連絡")
    end

    assert_equal [ @owner, @member ].map(&:id).sort,
                 Notification.pluck(:user_id).sort
  end

  test "自分自身には通知が作られない" do
    @conversation.messages.create!(sender: @owner, body: "企業からの連絡")

    assert_not Notification.exists?(user: @owner)
    assert Notification.exists?(user: @candidate)
  end

  test "選考の状況が変わると応募者にだけ通知が作られる" do
    # 企業側は自分たちで動かしているため、知らせる意味がない。
    assert_difference -> { Notification.where(kind: "stage_changed").count }, 1 do
      @job_application.move_to("interviewing", changed_by: @owner)
    end

    assert_equal @candidate, Notification.find_by(kind: "stage_changed").user
  end

  test "選考の状況の通知も、受け取りを無効にするとメールが送られない" do
    # 通知そのものは作られる。止まるのはメールだけである。
    @candidate.update!(email_notifications: false)

    assert_no_enqueued_jobs only: NotificationEmailJob do
      assert_difference -> { Notification.where(kind: "stage_changed").count }, 1 do
        @job_application.move_to("interviewing", changed_by: @owner)
      end
    end
  end

  test "選考の状況の通知は、受け取りが有効ならメールが積まれる" do
    assert_enqueued_jobs 1, only: NotificationEmailJob do
      @job_application.move_to("interviewing", changed_by: @owner)
    end
  end

  test "メールの受け取りが既定で有効である" do
    assert_predicate @candidate, :email_notifications?
  end

  test "受け取りを無効にするとメールは送られないが通知は作られる" do
    @owner.update!(email_notifications: false)
    @member.update!(email_notifications: false)

    assert_no_enqueued_jobs only: NotificationEmailJob do
      assert_difference -> { Notification.count }, 2 do
        @conversation.messages.create!(sender: @candidate, body: "応募者からの連絡")
      end
    end
  end

  test "受け取りが有効なら宛先の数だけメールが積まれる" do
    @member.update!(email_notifications: false)

    assert_enqueued_jobs 1, only: NotificationEmailJob do
      @conversation.messages.create!(sender: @candidate, body: "応募者からの連絡")
    end
  end

  test "通知の送信に失敗してもメッセージは保存されたままになる" do
    original = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = FailingQueueAdapter.new

    assert_raises(IOError) do
      @conversation.messages.create!(sender: @candidate, body: "応募者からの連絡")
    end

    assert_equal 1, Message.count
  ensure
    ActiveJob::Base.queue_adapter = original
  end

  test "通知の一覧を本人だけが見られる" do
    @conversation.messages.create!(sender: @candidate, body: "応募者からの連絡")
    sign_in_as(@owner)

    get notifications_path(locale: :ja)

    assert_response :success
    assert_select "main li", count: 1
  end

  test "他人の通知は一覧に出ない" do
    @conversation.messages.create!(sender: @candidate, body: "応募者からの連絡")
    sign_in_as(@candidate)

    get notifications_path(locale: :ja)

    assert_select "main li", count: 0
  end

  test "一覧を開くと既読になる" do
    @conversation.messages.create!(sender: @candidate, body: "応募者からの連絡")
    sign_in_as(@owner)

    get notifications_path(locale: :ja)

    assert_equal 0, @owner.notifications.unread.count
  end

  test "未読の件数がヘッダーに出る" do
    # 通知の一覧そのものは開いた時点で既読にするため、別の画面で確かめる。
    @conversation.messages.create!(sender: @candidate, body: "応募者からの連絡")
    sign_in_as(@owner)

    get account_path(locale: :ja)

    assert_select "header a", text: I18n.t("application.account.notifications", count: 1)
  end

  test "未ログインでは通知を扱えない" do
    get notifications_path(locale: :ja)

    assert_redirected_to new_session_path(locale: :ja)
  end

  test "メールの受け取りを設定できる" do
    sign_in_as(@candidate)

    patch notification_settings_path(locale: :ja), params: { email_notifications: "0" }

    assert_not_predicate @candidate.reload, :email_notifications?

    patch notification_settings_path(locale: :ja), params: { email_notifications: "1" }

    assert_predicate @candidate.reload, :email_notifications?
  end

  test "メールの本文に中身が含まれない" do
    # メールは転送も保存もされる経路であり、公開範囲の設定が効かない。
    @job_application.application_reviews.create!(reviewer: @owner, rating: 1, comment: "内部の評価")
    message = @conversation.messages.create!(sender: @candidate, body: "秘密の相談です")
    notification = Notification.find_by(user: @owner, message: message)

    mail = NotificationMailer.message_received(notification, locale: :ja)

    assert_no_match(/秘密の相談です/, mail.body.to_s)
    assert_no_match(/内部の評価/, mail.body.to_s)
  end

  test "メールを日本語と英語で送れる" do
    @conversation.messages.create!(sender: @candidate, body: "応募者からの連絡")
    notification = Notification.find_by(user: @owner)

    I18n.available_locales.each do |locale|
      mail = NotificationMailer.message_received(notification, locale: locale)

      assert_equal [ @owner.email_address ], mail.to
      assert_match(/#{locale}/, mail.body.to_s)
    end
  end

  test "通知の画面を日本語と英語で表示する" do
    sign_in_as(@candidate)

    I18n.available_locales.each do |locale|
      get notifications_path(locale: locale)

      assert_response :success
      assert_select "main h1", text: I18n.t("notifications.index.title", locale: locale)

      get edit_notification_settings_path(locale: locale)

      assert_response :success
    end
  end

  private
    def sign_in_as(user)
      post session_path(locale: :ja), params: { email_address: user.email_address, password: PASSWORD }
    end
end
