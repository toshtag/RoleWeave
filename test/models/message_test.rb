require "test_helper"

# メッセージと既読の契約を検証する。
#
# 経路の側でも重複を避けているが、値の規則そのものを確かめる。
class MessageTest < ActiveSupport::TestCase
  PASSWORD = "correct horse battery".freeze

  setup do
    candidate = User.create!(email_address: "candidate@example.com", password: PASSWORD).tap(&:confirm)
    @candidate_profile = candidate.create_candidate_profile!(display_name: "山田 太郎")
    @candidate = candidate

    @owner = User.create!(email_address: "owner@example.com", password: PASSWORD).tap(&:confirm)
    organization = Organization.create_with_owner!(name: "サンプル株式会社", user: @owner)
    job_posting = organization.job_postings.create!(
      title: "サンプルの求人", description: "仕事の内容", status: "published"
    )
    job_application = @candidate_profile.job_applications.create!(job_posting: job_posting)
    @conversation = Conversation.create!(job_application: job_application)
  end

  test "送った内容を後から変えられない" do
    # 相手が読んだものと食い違う。「言った・言わない」を作らない。
    message = @conversation.messages.create!(sender: @candidate, body: "最初の内容")

    assert_raises(ActiveRecord::ReadonlyAttributeError) { message.update!(body: "書き換えた内容") }
  end

  test "送信者を後から変えられない" do
    message = @conversation.messages.create!(sender: @candidate, body: "本文")

    assert_raises(ActiveRecord::ReadonlyAttributeError) { message.update!(sender_id: @owner.id) }
  end

  test "同じ人が同じメッセージを二重に読んだ記録を作れない" do
    message = @conversation.messages.create!(sender: @candidate, body: "本文")
    MessageRead.create!(message: message, user: @owner)

    assert_not MessageRead.new(message: message, user: @owner).valid?
  end

  test "検証を迂回した二重の既読をデータベースが拒否する" do
    message = @conversation.messages.create!(sender: @candidate, body: "本文")
    MessageRead.create!(message: message, user: @owner)

    assert_raises(ActiveRecord::RecordNotUnique) do
      MessageRead.insert_all!([ {
        message_id: message.id, user_id: @owner.id,
        created_at: Time.current, updated_at: Time.current
      } ])
    end
  end

  test "別の人であれば同じメッセージを読める" do
    message = @conversation.messages.create!(sender: @candidate, body: "本文")
    MessageRead.create!(message: message, user: @owner)

    assert_predicate MessageRead.new(message: message, user: @candidate), :valid?
  end

  test "メッセージを削除すると既読も消える" do
    message = @conversation.messages.create!(sender: @candidate, body: "本文")
    MessageRead.create!(message: message, user: @owner)

    assert_difference -> { MessageRead.count }, -1 do
      message.destroy
    end
  end

  test "会話は 1 つの応募に 1 つだけ" do
    assert_not Conversation.new(job_application: @conversation.job_application).valid?
  end
end
