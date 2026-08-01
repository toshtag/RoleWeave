require "test_helper"

# デモデータの契約を検証する。
#
# 検証対象は、架空であることと、二重に作られないことである。
class DemoDataTest < ActiveSupport::TestCase
  setup do
    # デモデータは development でのみ投入できる。テストでは判定を切り替えて確かめる。
    @original_env = Rails.env
  end

  teardown do
    Rails.env = @original_env
  end

  test "production では投入できない" do
    # 架空データが本番のデータベースへ入ると、本物と混ざる。
    Rails.env = "production"

    assert_raises(RuntimeError) { DemoData.new.seed }
  end

  test "production では削除もできない" do
    Rails.env = "production"

    assert_raises(RuntimeError) { DemoData.new.clean }
  end

  test "development では投入できる" do
    Rails.env = "development"

    assert_difference -> { User.where("email_address LIKE ?", "%@example.invalid").count }, 5 do
      DemoData.new.seed
    end
  ensure
    DemoData.new.clean
  end

  test "2 回実行しても二重に作られない" do
    Rails.env = "development"
    DemoData.new.seed

    assert_no_difference -> { User.count } do
      DemoData.new.seed
    end
  ensure
    DemoData.new.clean
  end

  test "メールアドレスがすべて実在しない領域である" do
    # RFC 2606 が予約する .invalid を使う。実在の相手へ届かない。
    assert_equal "example.invalid", DemoData::DOMAIN

    DemoData::ACCOUNTS.each_value do |account|
      assert_match(/@example\.invalid\z/, account[:email])
    end
  end

  test "画面が空にならないだけの中身が入る" do
    Rails.env = "development"
    DemoData.new.seed

    assert_operator JobPosting.published.count, :>=, 1
    assert_operator JobPosting.where(status: "draft").count, :>=, 1
    assert_operator JobPosting.where(status: "pending_review").count, :>=, 1
    assert_operator JobApplication.count, :>=, 2
    assert_operator ApplicationReview.count, :>=, 1
    assert_operator InterviewSchedule.count, :>=, 1
    assert_operator Message.count, :>=, 2
    assert_operator Notification.count, :>=, 1
    assert JobApplication.exists?(stage: "interviewing")
    assert User.exists?(operator: true)
  ensure
    DemoData.new.clean
  end

  test "消すとアカウントが残らない" do
    Rails.env = "development"
    DemoData.new.seed

    DemoData.new.clean

    assert_equal 0, User.where("email_address LIKE ?", "%@example.invalid").count
    assert_nil Organization.find_by(name: DemoData::ORGANIZATION_NAME)
  end
end
