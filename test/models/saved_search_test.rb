require "test_helper"

# 保存した求人と検索条件、新着の通知の契約を検証する。
class SavedSearchTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  PASSWORD = "correct horse battery".freeze

  setup do
    @candidate = User.create!(email_address: "candidate@example.com", password: PASSWORD).tap(&:confirm)
    @profile = @candidate.create_candidate_profile!(display_name: "山田 太郎")

    owner = User.create!(email_address: "owner@example.com", password: PASSWORD).tap(&:confirm)
    @organization = Organization.create_with_owner!(name: "サンプル株式会社", user: owner)
  end

  test "求人を保存でき、同じ求人を 2 回保存できない" do
    job_posting = published_job_posting

    assert @profile.saved_job_postings.create(job_posting: job_posting).persisted?
    assert_not @profile.saved_job_postings.build(job_posting: job_posting).valid?
  end

  test "検証を迂回した二重の保存をデータベースが拒否する" do
    job_posting = published_job_posting
    @profile.saved_job_postings.create!(job_posting: job_posting)

    assert_raises(ActiveRecord::RecordNotUnique) do
      SavedJobPosting.insert_all!([ {
        candidate_profile_id: @profile.id, job_posting_id: job_posting.id,
        created_at: Time.current, updated_at: Time.current
      } ])
    end
  end

  test "保存できる件数の上限を固定する" do
    # 値そのものを書く。定数を参照するだけのテストは、緩めたときに一緒に緩む。
    assert_equal 200, SavedJobPosting::MAX_PER_PROFILE
    assert_equal 20, SavedSearch::MAX_PER_PROFILE
  end

  test "上限を超える検索条件を保存できない" do
    SavedSearch::MAX_PER_PROFILE.times do |index|
      @profile.saved_searches.create!(name: "条件 #{index}", conditions: {})
    end

    assert_not @profile.saved_searches.build(name: "超過", conditions: {}).valid?
  end

  test "検索が使わない項目を条件にできない" do
    # 検索の側と食い違う条件が保存されると、再実行しても同じ結果にならない。
    assert_not @profile.saved_searches.build(name: "不正", conditions: { "secret" => "x" }).valid?
    assert_predicate @profile.saved_searches.build(name: "正しい", conditions: { "keyword" => "開発" }), :valid?
  end

  test "条件に一致する公開中の求人を引ける" do
    published_job_posting(title: "開発の求人", occupation: "開発")
    published_job_posting(title: "人事の求人", occupation: "人事")
    saved_search = @profile.saved_searches.create!(name: "開発", conditions: { "occupation" => "開発" })

    assert_equal [ "開発の求人" ], saved_search.matching_job_postings.pluck(:title)
  end

  test "前回の通知より後に公開された求人だけを通知する" do
    saved_search = @profile.saved_searches.create!(name: "すべて", conditions: {})
    published_job_posting(title: "保存より前の求人").update_column(:updated_at, 1.day.ago)

    assert_no_difference -> { Notification.where(kind: "new_job_postings").count } do
      NewJobPostingNotifier.new.run
    end

    published_job_posting(title: "保存より後の求人")

    assert_difference -> { Notification.where(kind: "new_job_postings").count }, 1 do
      NewJobPostingNotifier.new.run
    end

    assert_equal 1, Notification.where(kind: "new_job_postings").first.new_job_postings_count
    assert_not_nil saved_search.reload.notified_at
  end

  test "同じ求人を 2 回通知しない" do
    @profile.saved_searches.create!(name: "すべて", conditions: {})
    published_job_posting

    NewJobPostingNotifier.new.run

    assert_no_difference -> { Notification.count } do
      NewJobPostingNotifier.new.run
    end
  end

  test "条件に一致しない求人は通知されない" do
    @profile.saved_searches.create!(name: "開発", conditions: { "occupation" => "開発" })
    published_job_posting(title: "人事の求人", occupation: "人事")

    assert_no_difference -> { Notification.count } do
      NewJobPostingNotifier.new.run
    end
  end

  test "通知しない設定の条件は対象にならない" do
    @profile.saved_searches.create!(name: "すべて", conditions: {}, notify: false)
    published_job_posting

    assert_no_difference -> { Notification.count } do
      NewJobPostingNotifier.new.run
    end
  end

  test "メールの受け取りが無効なら skipped として残る" do
    @candidate.update!(email_notifications: false)
    @profile.saved_searches.create!(name: "すべて", conditions: {})
    published_job_posting

    assert_no_enqueued_jobs only: NotificationEmailJob do
      NewJobPostingNotifier.new.run
    end

    assert_equal "skipped", Notification.where(kind: "new_job_postings").first.email_status
  end

  test "メールの本文に求人の中身が含まれない" do
    @profile.saved_searches.create!(name: "すべて", conditions: {})
    published_job_posting(title: "秘密の求人")
    NewJobPostingNotifier.new.run
    notification = Notification.where(kind: "new_job_postings").first

    mail = NotificationMailer.new_job_postings(notification, locale: :ja)

    assert_no_match(/秘密の求人/, mail.body.to_s)
    assert_match(/1/, mail.body.to_s)
  end

  test "プロフィールを削除すると保存も消える" do
    @profile.saved_job_postings.create!(job_posting: published_job_posting)
    @profile.saved_searches.create!(name: "すべて", conditions: {})

    assert_difference -> { SavedJobPosting.count + SavedSearch.count }, -2 do
      @profile.destroy
    end
  end

  private
    def published_job_posting(title: "サンプルの求人", occupation: "人事")
      @organization.job_postings.create!(
        title: title, description: "仕事の内容", occupation: occupation, status: "published"
      )
    end
end
