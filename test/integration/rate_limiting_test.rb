require "test_helper"

# レート制限の契約を検証する。
#
# 検証対象は、上限を超えた試行が止まることと、画面が読めることである。
class RateLimitingTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct horse battery".freeze

  setup do
    @user = User.create!(email_address: "member@example.com", password: PASSWORD).tap(&:confirm)
  end

  test "上限までのログインの試行は通る" do
    ApplicationController::SIGN_IN_ATTEMPT_LIMIT.times do
      post session_path(locale: :ja), params: { email_address: @user.email_address, password: "wrong password" }

      assert_response :unprocessable_content
    end
  end

  test "上限を超えるログインの試行が 429 になる" do
    # 総当たりを抑える。
    exceed(ApplicationController::SIGN_IN_ATTEMPT_LIMIT) do
      post session_path(locale: :ja), params: { email_address: @user.email_address, password: "wrong password" }
    end

    assert_response :too_many_requests
  end

  test "上限を超える登録が 429 になる" do
    exceed(ApplicationController::SIGN_UP_ATTEMPT_LIMIT) do |index|
      post registration_path(locale: :ja),
           params: { user: { email_address: "new#{index}@example.com", password: PASSWORD } }
    end

    assert_response :too_many_requests
  end

  test "上限を超える再設定の依頼が 429 になる" do
    # メールの大量送信を抑える。
    exceed(ApplicationController::PASSWORD_RESET_ATTEMPT_LIMIT) do
      post password_reset_path(locale: :ja), params: { email_address: @user.email_address }
    end

    assert_response :too_many_requests
  end

  test "上限を超えるメッセージの送信が 429 になる" do
    conversation = prepare_conversation
    post session_path(locale: :ja), params: { email_address: @user.email_address, password: PASSWORD }

    exceed(ApplicationController::MESSAGE_ATTEMPT_LIMIT) do |index|
      post application_conversation_path(locale: :ja, application_id: conversation.job_application),
           params: { message: { body: "#{index} 通目" } }
    end

    assert_response :too_many_requests
  end

  test "429 の画面が日本語と英語で読める" do
    I18n.available_locales.each do |locale|
      Rails.cache.clear

      exceed(ApplicationController::SIGN_IN_ATTEMPT_LIMIT) do
        post session_path(locale: locale),
             params: { email_address: @user.email_address, password: "wrong password" }
      end

      assert_response :too_many_requests
      assert_select "html[lang=?]", locale.to_s
      assert_select "meta[name=?][content=?]", "robots", "noindex, nofollow"
    end
  end

  test "上限と期間が定数として 1 か所にある" do
    # 経路ごとに書くと、片方だけ緩めた状態が生まれる。
    assert_equal 5.minutes, ApplicationController::RATE_LIMIT_PERIOD
    assert_operator ApplicationController::SIGN_IN_ATTEMPT_LIMIT, :>, 0
    assert_operator ApplicationController::MESSAGE_ATTEMPT_LIMIT, :>,
                    ApplicationController::SIGN_UP_ATTEMPT_LIMIT
  end

  private
    def exceed(limit)
      (limit + 1).times { |index| yield index }
    end

    def prepare_conversation
      profile = @user.create_candidate_profile!(display_name: "山田 太郎")
      owner = User.create!(email_address: "owner@example.com", password: PASSWORD).tap(&:confirm)
      organization = Organization.create_with_owner!(name: "サンプル株式会社", user: owner)
      job_posting = organization.job_postings.create!(
        title: "サンプルの求人", description: "仕事の内容", status: "published"
      )
      application = profile.job_applications.create!(job_posting: job_posting)

      Conversation.create!(job_application: application)
    end
end
