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
end
