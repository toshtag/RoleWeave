require "test_helper"

# 応募に紐づく会話の契約を検証する。
#
# 検証対象は、誰が読み書きできるかと、既読の記録である。
class ConversationTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct horse battery".freeze

  setup do
    @candidate = User.create!(email_address: "candidate@example.com", password: PASSWORD).tap(&:confirm)
    @candidate_profile = @candidate.create_candidate_profile!(display_name: "山田 太郎")

    @owner = User.create!(email_address: "owner@example.com", password: PASSWORD).tap(&:confirm)
    @organization = Organization.create_with_owner!(name: "サンプル株式会社", user: @owner)

    @job_posting = @organization.job_postings.create!(
      title: "サンプルの求人", description: "仕事の内容", status: "published"
    )
    @job_application = @candidate_profile.job_applications.create!(job_posting: @job_posting)
  end

  test "未ログインでは会話を扱えない" do
    get conversation_path

    assert_redirected_to new_session_path(locale: :ja)
  end

  test "メールアドレスが未確認では会話を扱えない" do
    unconfirmed = User.create!(email_address: "unconfirmed@example.com", password: PASSWORD)
    sign_in_as(unconfirmed)

    get conversation_path

    assert_response :forbidden
  end

  test "応募者がメッセージを送れる" do
    sign_in_as(@candidate)

    assert_difference -> { Message.count }, 1 do
      post conversation_path, params: { message: { body: "よろしくお願いします" } }
    end

    assert_equal @candidate, Message.sole.sender
  end

  test "組織の所属者が同じ会話へ送れる" do
    sign_in_as(@candidate)
    post conversation_path, params: { message: { body: "応募者からの連絡" } }
    sign_in_as(@owner)

    assert_difference -> { Message.count }, 1 do
      post conversation_path, params: { message: { body: "企業からの返信" } }
    end

    assert_equal 1, Conversation.count
  end

  test "空のメッセージを送れない" do
    sign_in_as(@candidate)

    assert_no_difference -> { Message.count } do
      post conversation_path, params: { message: { body: "  " } }
    end

    assert_equal I18n.t("conversations.create.invalid"), flash[:alert]
  end

  test "上限を超えるメッセージを送れない" do
    sign_in_as(@candidate)

    assert_no_difference -> { Message.count } do
      post conversation_path, params: { message: { body: "a" * (Message::BODY_MAX_LENGTH + 1) } }
    end
  end

  test "無関係な利用者は会話を読めない" do
    sign_in_as(User.create!(email_address: "outsider@example.com", password: PASSWORD).tap(&:confirm))

    get conversation_path

    assert_response :not_found
  end

  test "他組織の所属者は会話を読めない" do
    outsider = User.create!(email_address: "other-owner@example.com", password: PASSWORD).tap(&:confirm)
    Organization.create_with_owner!(name: "別の会社", user: outsider)
    sign_in_as(outsider)

    get conversation_path

    assert_response :not_found
  end

  test "取り消された応募では新しいメッセージを送れない" do
    sign_in_as(@candidate)
    post conversation_path, params: { message: { body: "取消の前の連絡" } }
    @job_application.withdraw

    assert_no_difference -> { Message.count } do
      post conversation_path, params: { message: { body: "取消の後の連絡" } }
    end

    assert_equal I18n.t("conversations.create.closed"), flash[:alert]
  end

  test "取り消された応募でも読める" do
    # やり取りは選考の記録である。
    sign_in_as(@candidate)
    post conversation_path, params: { message: { body: "取消の前の連絡" } }
    @job_application.withdraw

    get conversation_path

    assert_response :success
    assert_select "main", text: /取消の前の連絡/
  end

  test "会話を開くと相手のメッセージが既読になる" do
    sign_in_as(@candidate)
    post conversation_path, params: { message: { body: "応募者からの連絡" } }
    sign_in_as(@owner)

    assert_difference -> { MessageRead.count }, 1 do
      get conversation_path
    end

    assert Message.sole.read_by?(@owner)
  end

  test "自分が送ったメッセージは既読の対象にならない" do
    sign_in_as(@candidate)
    post conversation_path, params: { message: { body: "応募者からの連絡" } }

    assert_no_difference -> { MessageRead.count } do
      get conversation_path
    end
  end

  test "同じメッセージの既読が二重に記録されない" do
    sign_in_as(@candidate)
    post conversation_path, params: { message: { body: "応募者からの連絡" } }
    sign_in_as(@owner)
    get conversation_path

    assert_no_difference -> { MessageRead.count } do
      get conversation_path
    end
  end

  test "未読の件数が分かる" do
    sign_in_as(@candidate)
    post conversation_path, params: { message: { body: "1 通目" } }
    post conversation_path, params: { message: { body: "2 通目" } }

    conversation = @job_application.reload.conversation

    assert_equal 2, conversation.unread_count_for(@owner)
    assert_equal 0, conversation.unread_count_for(@candidate)
  end

  test "送信者を削除してもメッセージは残る" do
    sign_in_as(@candidate)
    post conversation_path, params: { message: { body: "応募者からの連絡" } }

    another_owner = User.create!(email_address: "owner2@example.com", password: PASSWORD)
    @organization.memberships.create!(user: another_owner, role: "owner", changed_by: @owner)

    assert_no_difference -> { Message.count } do
      AccountDeletion.new(@owner).delete!
    end
  end

  test "応募を削除すると会話とメッセージも消える" do
    sign_in_as(@candidate)
    post conversation_path, params: { message: { body: "応募者からの連絡" } }

    assert_difference -> { Message.count }, -1 do
      @job_application.destroy
    end

    assert_equal 0, Conversation.count
  end

  test "会話の画面を日本語と英語で表示する" do
    sign_in_as(@candidate)

    I18n.available_locales.each do |locale|
      get application_conversation_path(locale: locale, application_id: @job_application)

      assert_response :success
      assert_select "main h1", text: I18n.t("conversations.show.title", locale: locale)
    end
  end

  private
    def sign_in_as(user)
      post session_path(locale: :ja), params: { email_address: user.email_address, password: PASSWORD }
    end

    def conversation_path
      application_conversation_path(locale: :ja, application_id: @job_application)
    end
end
