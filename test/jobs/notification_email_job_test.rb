require "test_helper"

# 通知メールの配信の記録の契約を検証する。
#
# 検証対象は、成功と失敗が残ることと、失敗が握り潰されないことである。
class NotificationEmailJobTest < ActiveJob::TestCase
  PASSWORD = "correct horse battery".freeze

  setup do
    candidate = User.create!(email_address: "candidate@example.com", password: PASSWORD).tap(&:confirm)
    candidate_profile = candidate.create_candidate_profile!(display_name: "山田 太郎")

    @owner = User.create!(email_address: "owner@example.com", password: PASSWORD).tap(&:confirm)
    organization = Organization.create_with_owner!(name: "サンプル株式会社", user: @owner)
    job_posting = organization.job_postings.create!(
      title: "サンプルの求人", description: "仕事の内容", status: "published"
    )
    @job_application = candidate_profile.job_applications.create!(job_posting: job_posting)
    @notification = Notification.create!(
      user: @owner, job_application: @job_application, kind: "stage_changed"
    )
  end

  test "積まれた時点では pending である" do
    assert_equal "pending", @notification.email_status
  end

  test "送信に成功すると delivered になり時刻が残る" do
    NotificationEmailJob.perform_now(@notification, locale: :ja)

    @notification.reload

    assert_equal "delivered", @notification.email_status
    assert_not_nil @notification.email_delivered_at
    assert_nil @notification.email_error
  end

  test "送信に失敗すると failed になり、内容と回数が残る" do
    # 失敗の内容をそのまま残す。運営者が原因を追えるようにする。
    assert_raises(ArgumentError) do
      NotificationEmailJob.perform_now(broken_notification, locale: :ja)
    end

    broken_notification.reload

    assert_equal "failed", broken_notification.email_status
    assert_equal 1, broken_notification.email_attempts
    assert_match(/ArgumentError/, broken_notification.email_error)
  end

  test "失敗を握り潰さない" do
    # 握り潰すと、ジョブの再試行が働かなくなる。
    assert_raises(ArgumentError) do
      NotificationEmailJob.perform_now(broken_notification, locale: :ja)
    end
  end

  test "失敗しても通知そのものは残る" do
    target = broken_notification

    assert_no_difference -> { Notification.count } do
      assert_raises(ArgumentError) { NotificationEmailJob.perform_now(target, locale: :ja) }
    end

    assert Notification.exists?(target.id)
  end

  test "繰り返し失敗すると回数が増える" do
    2.times do
      assert_raises(ArgumentError) { NotificationEmailJob.perform_now(broken_notification, locale: :ja) }
    end

    assert_equal 2, broken_notification.reload.email_attempts
  end

  private
    # 種類が未知の通知は組み立てに失敗する。失敗の経路を通すために使う。
    def broken_notification
      @broken_notification ||= Notification.create!(
        user: @owner, job_application: @job_application, kind: "stage_changed"
      ).tap do |notification|
        # kind は書き換えられない属性である。検証の都合で直接書き換える。
        Notification.where(id: notification.id).update_all(kind: "unknown_kind")
        notification.reload
      end
    end
end
