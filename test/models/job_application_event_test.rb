require "test_helper"

# 応募の記録と通知の契約を検証する。
#
# 検証対象は、何が記録に残るかと、通知の失敗が応募に波及しないことである。
class JobApplicationEventTest < ActiveSupport::TestCase
  # 通知は非同期に積まれる。積まれたことを数えるための補助を取り込む。
  include ActionMailer::TestHelper

  # 通知を積む処理そのものが失敗する状況を作るための差し替え先。
  class FailingQueueAdapter
    def enqueue(*) = raise(IOError, "送信できない")
    def enqueue_at(*) = raise(IOError, "送信できない")
  end

  PASSWORD = "correct horse battery".freeze

  setup do
    candidate = User.create!(email_address: "candidate@example.com", password: PASSWORD).tap(&:confirm)
    @candidate_profile = candidate.create_candidate_profile!(display_name: "山田 太郎")

    @owner = User.create!(email_address: "owner@example.com", password: PASSWORD).tap(&:confirm)
    @organization = Organization.create_with_owner!(name: "サンプル株式会社", user: @owner)
    @job_posting = @organization.job_postings.create!(
      title: "サンプルの求人", description: "仕事の内容", status: "published"
    )
  end

  test "応募すると記録が 1 件増える" do
    assert_difference -> { JobApplicationEvent.count }, 1 do
      apply
    end

    event = JobApplicationEvent.sole

    assert_equal "submitted", event.kind
    assert_equal @organization, event.organization
  end

  test "取り消すと記録がもう 1 件増える" do
    job_application = apply

    assert_difference -> { JobApplicationEvent.count }, 1 do
      job_application.withdraw
    end

    assert_equal "withdrawn", JobApplicationEvent.recent.first.kind
  end

  test "取消でない更新では記録が増えない" do
    job_application = apply

    assert_no_difference -> { JobApplicationEvent.count } do
      job_application.touch
    end
  end

  test "記録に求人の題名と応募者の表示名が写る" do
    apply

    event = JobApplicationEvent.sole

    assert_equal "サンプルの求人", event.job_posting_title
    assert_equal "山田 太郎", event.candidate_display_name
  end

  test "応募を削除しても記録は残り、参照が空になる" do
    apply.destroy

    event = JobApplicationEvent.sole

    assert_nil event.job_application
    assert_equal "サンプルの求人", event.job_posting_title
  end

  test "プロフィールを削除しても記録は残る" do
    apply

    assert_no_difference -> { JobApplicationEvent.count } do
      @candidate_profile.destroy
    end

    assert_equal "山田 太郎", JobApplicationEvent.first.candidate_display_name
  end

  test "記録の内容を後から書き換えられない" do
    apply

    assert_raises(ActiveRecord::ReadonlyAttributeError) do
      JobApplicationEvent.sole.update!(candidate_display_name: "書き換えた名前")
    end
  end

  test "応募すると組織の管理者宛に通知が積まれる" do
    assert_enqueued_emails 1 do
      apply
    end
  end

  test "通知は一般の所属者へは送らない" do
    member = User.create!(email_address: "member@example.com", password: PASSWORD).tap(&:confirm)
    Membership.create!(organization: @organization, user: member, role: "member")

    assert_enqueued_emails 1 do
      apply
    end
  end

  test "管理者が 2 人いれば 2 通積まれる" do
    another_owner = User.create!(email_address: "owner2@example.com", password: PASSWORD).tap(&:confirm)
    @organization.memberships.create!(user: another_owner, role: "owner", changed_by: @owner)

    assert_enqueued_emails 2 do
      apply
    end
  end

  test "取消では通知を積まない" do
    job_application = apply

    assert_no_enqueued_emails do
      job_application.withdraw
    end
  end

  test "通知の送信に失敗しても応募は保存されたままになる" do
    # 通知はトランザクションが閉じた後に積む。
    # 同じトランザクションの中で送ると、メールが送れないだけで応募が失敗する。
    original = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = FailingQueueAdapter.new

    assert_raises(IOError) { apply }

    assert_equal 1, JobApplication.count
    assert_equal 1, JobApplicationEvent.count
  ensure
    ActiveJob::Base.queue_adapter = original
  end

  test "メールの本文に応募者の経歴が含まれない" do
    # メールは転送も保存もされる経路であり、公開範囲の設定が効かない。
    @candidate_profile.work_experiences.create!(
      organization_name: "秘密の会社", position: "秘密の役職", started_on: Date.new(2020, 4, 1)
    )
    job_application = apply

    mail = OrganizationMailer.job_application(job_application, to: @owner.email_address, locale: :ja)

    assert_no_match(/秘密の会社/, mail.body.to_s)
    assert_no_match(/秘密の役職/, mail.body.to_s)
    assert_match(/サンプルの求人/, mail.body.to_s)
  end

  test "メールを日本語と英語で送れる" do
    job_application = apply

    I18n.available_locales.each do |locale|
      mail = OrganizationMailer.job_application(job_application, to: @owner.email_address, locale: locale)

      assert_equal [ @owner.email_address ], mail.to
      assert_match(/#{locale}/, mail.body.to_s)
    end
  end

  private
    def apply
      @candidate_profile.job_applications.create!(job_posting: @job_posting)
    end
end
