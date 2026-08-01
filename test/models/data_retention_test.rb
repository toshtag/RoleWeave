require "test_helper"

# 保持期限の契約を検証する。
#
# 検証対象は、期限を過ぎたものだけが対象になることと、
# 表の扱いが必ず決まっていることである。
class DataRetentionTest < ActiveSupport::TestCase
  PASSWORD = "correct horse battery".freeze

  setup do
    @user = User.create!(email_address: "member@example.com", password: PASSWORD).tap(&:confirm)
  end

  test "すべての表が、対象か対象外かのどちらかに入っている" do
    # 決めていない表があると、個人情報が無期限に残りうる。
    # 落ちた場合は、期間を決めるか、対象にしない理由を書く。
    described = DataRetention::POLICIES.keys + DataRetention::EXCLUDED_TABLES.keys
    tables = ActiveRecord::Base.connection.tables - %w[schema_migrations ar_internal_metadata]

    assert_equal tables.sort, described.sort
  end

  test "対象にしない表には理由が書かれている" do
    DataRetention::EXCLUDED_TABLES.each do |table, reason|
      assert_not_empty reason.to_s, "#{table} の理由"
    end
  end

  test "対象の表には期間と扱いが決まっている" do
    DataRetention::POLICIES.each do |table, policy|
      assert_kind_of ActiveSupport::Duration, policy.fetch(:period), "#{table} の期間"
      assert_includes %i[delete anonymize], policy.fetch(:strategy), "#{table} の扱い"
      assert_not_empty policy.fetch(:reason).to_s, "#{table} の理由"
    end
  end

  test "期間と扱いの値を固定する" do
  # 値そのものを書く。定数を参照するだけのテストは、
  # 期間を縮めたり伸ばしたりしても一緒に動いてしまう。
  assert_equal 90.days, DataRetention::POLICIES.fetch("sessions").fetch(:period)
  assert_equal :delete, DataRetention::POLICIES.fetch("sessions").fetch(:strategy)
  assert_equal 180.days, DataRetention::POLICIES.fetch("notifications").fetch(:period)
  assert_equal :delete, DataRetention::POLICIES.fetch("notifications").fetch(:strategy)
  assert_equal 1.year, DataRetention::POLICIES.fetch("authentication_events").fetch(:period)
  assert_equal :anonymize, DataRetention::POLICIES.fetch("authentication_events").fetch(:strategy)
end

test "期限を過ぎたセッションを削除する" do
    old_session = @user.sessions.create!
    old_session.update_column(:created_at, 91.days.ago)
    fresh_session = @user.sessions.create!

    DataRetention.new.apply

    assert_not Session.exists?(old_session.id)
    assert Session.exists?(fresh_session.id)
  end

  test "期限を過ぎた通知を削除する" do
    old_notification = Notification.create!(user: @user, kind: "stage_changed")
    old_notification.update_column(:created_at, 181.days.ago)
    fresh_notification = Notification.create!(user: @user, kind: "stage_changed")

    DataRetention.new.apply

    assert_not Notification.exists?(old_notification.id)
    assert Notification.exists?(fresh_notification.id)
  end

  test "期限を過ぎた認証の記録を匿名化する。記録そのものは残る" do
    # いつ何が起きたかは監査に要る（ADR 0010）。
    old_event = AuthenticationEvent.record(kind: "sign_in_succeeded",
                                           email_address: @user.email_address, user: @user)
    old_event.update_column(:created_at, 366.days.ago)

    assert_no_difference -> { AuthenticationEvent.count } do
      DataRetention.new.apply
    end

    old_event.reload

    assert_equal AccountDeletion::ANONYMIZED_EMAIL_ADDRESS, old_event.email_address
    assert_nil old_event.user_id
  end

  test "期限内の認証の記録は変えない" do
    event = AuthenticationEvent.record(kind: "sign_in_succeeded",
                                       email_address: @user.email_address, user: @user)

    DataRetention.new.apply

    assert_equal @user.email_address, event.reload.email_address
  end

  test "確認は何も変えない" do
    old_session = @user.sessions.create!
    old_session.update_column(:created_at, 91.days.ago)

    report = DataRetention.new.report

    assert_equal 1, report["sessions"]
    assert Session.exists?(old_session.id)
  end

  test "件数を返す" do
    old_session = @user.sessions.create!
    old_session.update_column(:created_at, 91.days.ago)

    assert_equal 1, DataRetention.new.apply["sessions"]
  end

  test "基準の時刻を渡せる" do
    session = @user.sessions.create!

    # いまから 1 年後の視点では、いま作ったセッションも期限を過ぎている。
    assert_equal 1, DataRetention.new(now: 1.year.from_now).report["sessions"]
    assert Session.exists?(session.id)
  end
end
