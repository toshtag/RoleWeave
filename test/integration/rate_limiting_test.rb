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

  test "上限までの招待は通り、メールが 1 通ずつ積まれる" do
    organization = owned_organization
    sign_in_as(@user)

    assert_difference -> { Invitation.count }, ApplicationController::INVITATION_ATTEMPT_LIMIT do
      assert_enqueued_emails ApplicationController::INVITATION_ATTEMPT_LIMIT do
        ApplicationController::INVITATION_ATTEMPT_LIMIT.times { |index| invite(organization, index) }
      end
    end
  end

  test "上限を超える招待が 429 になり、行もメールも増えない" do
    # 任意の宛先へメールを積める経路である。招待そのものに一意制約はあるが、
    # 宛先を変えれば何度でも作れる。
    organization = owned_organization
    sign_in_as(@user)

    exceed(ApplicationController::INVITATION_ATTEMPT_LIMIT) do |index|
      @before = [ Invitation.count, enqueued_jobs.size ]
      invite(organization, index)
    end

    assert_response :too_many_requests
    assert_equal @before, [ Invitation.count, enqueued_jobs.size ]
  end

  test "未認証の要求は招待の枠を消費しない" do
    # 枠を数えるのは、認証・メールの確認・組織の解決・組織の管理者の判定を
    # 通った要求だけとする。
    # 通らない要求で減らせると、同じ IP の正規の管理者を止められる。
    organization = owned_organization

    exceed(ApplicationController::INVITATION_ATTEMPT_LIMIT) { |index| invite(organization, index) }

    assert_redirected_to new_session_path(locale: :ja)
    assert_equal 0, Invitation.count

    sign_in_as(@user)

    assert_difference -> { Invitation.count }, 1 do
      invite(organization, 9_000)
    end
  end

  test "メールが未確認の利用者の要求は招待の枠を消費しない" do
    organization = owned_organization
    unconfirmed = User.create!(email_address: "unconfirmed@example.com", password: PASSWORD)
    sign_in_as(unconfirmed)

    exceed(ApplicationController::INVITATION_ATTEMPT_LIMIT) { |index| invite(organization, index) }

    assert_response :forbidden

    sign_in_as(@user)

    assert_difference -> { Invitation.count }, 1 do
      invite(organization, 9_000)
    end
  end

  test "管理者でない利用者の要求は招待の枠を消費しない" do
    organization = owned_organization
    member = User.create!(email_address: "member2@example.com", password: PASSWORD).tap(&:confirm)
    organization.memberships.create!(user: member, role: "member", changed_by: @user)
    sign_in_as(member)

    exceed(ApplicationController::INVITATION_ATTEMPT_LIMIT) { |index| invite(organization, index) }

    assert_response :not_found

    sign_in_as(@user)

    assert_difference -> { Invitation.count }, 1 do
      invite(organization, 9_000)
    end
  end

  test "組織を切り替えても招待の上限は保たれる" do
    # 組織は確認済みのアカウントであれば作れる。
    # 組織ごとに数えると、作り直すだけで上限を迂回できる。
    first = owned_organization("最初の会社")
    second = owned_organization("次の会社")
    sign_in_as(@user)

    ApplicationController::INVITATION_ATTEMPT_LIMIT.times { |index| invite(first, index) }
    invite(second, 0)

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

  test "上限と期間の値を固定する" do
    # 値そのものを書く。定数を参照するだけのテストは、
    # 定数を緩めたときに一緒に緩んでしまう。
    assert_equal 5.minutes, ApplicationController::RATE_LIMIT_PERIOD
    assert_equal 10, ApplicationController::SIGN_IN_ATTEMPT_LIMIT
    assert_equal 5, ApplicationController::SIGN_UP_ATTEMPT_LIMIT
    assert_equal 5, ApplicationController::PASSWORD_RESET_ATTEMPT_LIMIT
    assert_equal 30, ApplicationController::MESSAGE_ATTEMPT_LIMIT
    assert_equal 10, ApplicationController::INVITATION_ATTEMPT_LIMIT
  end

  private
    def owned_organization(name = "サンプル株式会社")
      Organization.create_with_owner!(name: name, user: @user)
    end

    def sign_in_as(user)
      post session_path(locale: :ja), params: { email_address: user.email_address, password: PASSWORD }
    end

    # 宛先を毎回変える。同じ宛先への未受諾の招待には一意制約がある。
    def invite(organization, index)
      post organization_invitations_path(locale: :ja, organization_id: organization),
           params: { invitation: { email_address: "invited#{index}@example.invalid", role: "member" } }
    end

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
