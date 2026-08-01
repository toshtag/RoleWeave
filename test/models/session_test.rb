require "test_helper"

# ログイン状態を表すレコードの契約を検証する。
#
# 検証対象は、セッションとアカウントの関係である。
# Cookie の扱いと認証の成否は sign_in_test が持つ。
class SessionTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email_address: "member@example.com", password: "correct horse battery")
  end

  test "アカウントのないセッションを作れない" do
    assert_not Session.new.valid?
  end

  test "アカウントを削除するとセッションも消える" do
    @user.sessions.create!

    assert_difference -> { Session.count }, -1 do
      @user.destroy
    end
  end

  test "参照先のないセッションをデータベースが拒否する" do
    # 検証を迂回した保存でも、参照先のないセッションが残らないようにする。
    assert_raises(ActiveRecord::InvalidForeignKey) do
      Session.insert_all!([ {
        user_id: 0,
        last_active_at: Time.current,
        created_at: Time.current,
        updated_at: Time.current
      } ])
    end
  end

  test "同じアカウントで複数のセッションを持てる" do
    # 端末ごとにログインできる。1 つに制限すると、別の端末でログインするたびに
    # 元の端末が切断される。
    2.times { @user.sessions.create! }

    assert_equal 2, @user.sessions.count
  end
  test "期限内のセッションを期限切れとしない" do
    assert_not @user.sessions.create!.expired?
  end

  test "無操作の上限を超えたセッションを期限切れとする" do
    session = @user.sessions.create!
    session.update_column(:last_active_at, Session::IDLE_TIMEOUT.ago - 1.second)

    assert_predicate session.reload, :expired?
  end

  test "無操作の上限と同じ時点では期限切れとしない" do
    # 境界を含めて切ると、上限の意味が 1 秒ずれる。
    session = @user.sessions.create!
    session.update_column(:last_active_at, Session::IDLE_TIMEOUT.ago + 1.second)

    assert_not session.reload.expired?
  end

  test "発行からの上限を超えたセッションを期限切れとする" do
    # 使い続けている限り無操作の上限は来ない。発行からの上限がないと期限が来ない。
    session = @user.sessions.create!
    session.update_columns(created_at: Session::ABSOLUTE_TIMEOUT.ago - 1.second, last_active_at: Time.current)

    assert_predicate session.reload, :expired?
  end

  test "Cookie の期限を発行からの上限に合わせる" do
    session = @user.sessions.create!

    assert_equal session.created_at + Session::ABSOLUTE_TIMEOUT, session.cookie_expires_at
  end

  test "最終利用時刻を間隔を空けて更新する" do
    # リクエストのたびに更新すると、読み出しだけの操作でも毎回書き込みが起こる。
    session = @user.sessions.create!
    recorded_at = Session::ACTIVITY_UPDATE_INTERVAL.ago + 1.minute
    session.update_column(:last_active_at, recorded_at)

    session.reload.touch_activity

    assert_equal recorded_at.to_i, session.reload.last_active_at.to_i
  end

  test "間隔を過ぎたら最終利用時刻を更新する" do
    session = @user.sessions.create!
    session.update_column(:last_active_at, Session::ACTIVITY_UPDATE_INTERVAL.ago - 1.minute)

    session.reload.touch_activity

    assert_operator session.reload.last_active_at, :>, Session::ACTIVITY_UPDATE_INTERVAL.ago
  end
end
