require "test_helper"

# スカウトの契約を検証する。
#
# 検証対象は、送りすぎと望まない受信が止まることである。
class ScoutingTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  PASSWORD = "correct horse battery".freeze

  setup do
    @recruiter = User.create!(email_address: "recruiter@example.com", password: PASSWORD).tap(&:confirm)
    @organization = Organization.create_with_owner!(name: "サンプル株式会社", user: @recruiter)

    @candidate = User.create!(email_address: "candidate@example.com", password: PASSWORD).tap(&:confirm)
    @profile = @candidate.create_candidate_profile!(
      display_name: "山田 太郎", visibility: "all_organizations", scout_opt_in: true
    )
  end

  test "探せる候補者へ送れる" do
    sign_in_as(@recruiter)

    assert_difference -> { Scout.count }, 1 do
      post scouts_path, params: { candidate_profile_id: @profile.id, body: "ご連絡しました" }
    end

    assert_equal @recruiter, Scout.sole.sent_by
  end

  test "同じ候補者へ 2 通目を送れない" do
    @organization.scouts.create!(candidate_profile: @profile, body: "1 通目")
    sign_in_as(@recruiter)

    assert_no_difference -> { Scout.count } do
      post scouts_path, params: { candidate_profile_id: @profile.id, body: "2 通目" }
    end

    assert_response :unprocessable_content
  end

  test "検証を迂回した 2 通目をデータベースが拒否する" do
    @organization.scouts.create!(candidate_profile: @profile, body: "1 通目")

    assert_raises(ActiveRecord::RecordNotUnique) do
      Scout.insert_all!([ {
        organization_id: @organization.id, candidate_profile_id: @profile.id,
        body: "2 通目", created_at: Time.current, updated_at: Time.current
      } ])
    end
  end

  test "1 日の送信の上限を固定する" do
    # 値そのものを書く。定数を参照するだけのテストは、緩めたときに一緒に緩む。
    assert_equal 50, Scout::DAILY_LIMIT_PER_ORGANIZATION
  end

  test "上限を超えると送れない" do
    # 上限の数だけ作る。ただし作る数には天井を置く。
    # 定数を緩める変異を入れたときに、テストが巨大なデータを作りに行かないようにする。
    fill_scouts([ Scout::DAILY_LIMIT_PER_ORGANIZATION, 60 ].min)

    assert_not @organization.scouts.build(candidate_profile: @profile, body: "上限超過").valid?
  end

  test "上限の判定と保存を、組織の行を押さえたまま行う" do
    # 数えてから INSERT するまでの間に別の送信が入ると、
    # 両方が上限内だと判断して合計が上限を超える。
    # 数える前に組織の行を押さえ、同じ組織の送信を 1 つずつ通す。
    sign_in_as(@recruiter)

    statements = captured_sql do
      post scouts_path, params: { candidate_profile_id: @profile.id, body: "ご連絡しました" }
    end

    lock = statements.index { |sql| sql.match?(/SELECT.+FROM "organizations".+FOR UPDATE/m) }
    count = statements.index { |sql| sql.match?(/SELECT COUNT\(\*\).+FROM "scouts"/m) }
    insert = statements.index { |sql| sql.start_with?("INSERT INTO \"scouts\"") }

    assert lock, "組織の行を FOR UPDATE で押さえていない"
    assert count, "当日の件数を数えていない"
    assert insert, "スカウトを保存していない"
    assert lock < count, "件数を数える前に組織の行を押さえていない"
    assert count < insert, "数えた後に保存していない"
  end

  test "受信を許可していない候補者へ送れない" do
    @profile.update!(scout_opt_in: false)
    sign_in_as(@recruiter)

    post scouts_path, params: { candidate_profile_id: @profile.id, body: "本文" }

    assert_response :not_found
    assert_equal 0, Scout.count
  end

  test "配信を止めた組織から送れない" do
    @profile.scout_blocks.create!(organization: @organization)
    sign_in_as(@recruiter)

    assert_no_difference -> { Scout.count } do
      post scouts_path, params: { candidate_profile_id: @profile.id, body: "本文" }
    end
  end

  test "候補者が受け取ったスカウトを見て、配信を止められる" do
    @organization.scouts.create!(candidate_profile: @profile, body: "ご連絡しました")
    sign_in_as(@candidate)

    get profile_scouts_path(locale: :ja)

    assert_response :success
    assert_select "main", text: /ご連絡しました/

    assert_difference -> { ScoutBlock.count }, 1 do
      post profile_scout_blocks_path(locale: :ja, organization_id: @organization.id)
    end
  end

  test "送られていない組織の配信は止められない" do
    # 任意の組織を指定させない。
    outsider = User.create!(email_address: "outsider@example.com", password: PASSWORD).tap(&:confirm)
    other_organization = Organization.create_with_owner!(name: "別の会社", user: outsider)
    sign_in_as(@candidate)

    post profile_scout_blocks_path(locale: :ja, organization_id: other_organization.id)

    assert_response :not_found
  end

  test "受信で通知が作られ、メールが積まれる" do
    sign_in_as(@recruiter)

    assert_difference -> { Notification.where(kind: "scout_received").count }, 1 do
      assert_enqueued_jobs 1, only: NotificationEmailJob do
        post scouts_path, params: { candidate_profile_id: @profile.id, body: "本文" }
      end
    end
  end

  test "メールの本文にスカウトの本文が含まれない" do
    @organization.scouts.create!(candidate_profile: @profile, body: "秘密の本文")
    notification = Notification.create!(user: @candidate, kind: "scout_received", scout: Scout.sole)

    mail = NotificationMailer.scout_received(notification, locale: :ja)

    assert_no_match(/秘密の本文/, mail.body.to_s)
    assert_match(/サンプル株式会社/, mail.body.to_s)
  end

  test "送信が監査ログに残る" do
    sign_in_as(@recruiter)

    assert_difference -> { AccessEvent.where(action: "scout_sent").count }, 1 do
      post scouts_path, params: { candidate_profile_id: @profile.id, body: "本文" }
    end
  end

  test "テンプレートを作れ、他組織からは扱えない" do
    outsider = User.create!(email_address: "outsider@example.com", password: PASSWORD).tap(&:confirm)
    other_organization = Organization.create_with_owner!(name: "別の会社", user: outsider)
    sign_in_as(@recruiter)

    post organization_scout_templates_path(locale: :ja, organization_id: @organization),
         params: { scout_template: { name: "定型", body: "本文" } }

    assert_equal 1, ScoutTemplate.count

    sign_in_as(outsider)

    get organization_scout_templates_path(locale: :ja, organization_id: @organization)

    assert_response :not_found

    get organization_scout_templates_path(locale: :ja, organization_id: other_organization)

    assert_response :success
    assert_no_match(/定型/, response.body)
  end

  test "スカウトの画面を日本語と英語で表示する" do
    @organization.scouts.create!(candidate_profile: @profile, body: "本文")
    sign_in_as(@recruiter)

    I18n.available_locales.each do |locale|
      get organization_scouts_path(locale: locale, organization_id: @organization)

      assert_response :success
      assert_select "main h1", text: I18n.t("organizations.scouts.index.title", locale: locale)
    end

    sign_in_as(@candidate)

    I18n.available_locales.each do |locale|
      get profile_scouts_path(locale: locale)

      assert_response :success
      assert_select "main h1", text: I18n.t("candidate_scouts.index.title", locale: locale)
    end
  end

  private
    def sign_in_as(user)
      post session_path(locale: :ja), params: { email_address: user.email_address, password: PASSWORD }
    end

    def scouts_path
      organization_scouts_path(locale: :ja, organization_id: @organization)
    end

    # 上限の検証のために、候補者とスカウトをまとめて作る。
    # 1 件ずつ作ると、パスワードの計算だけで時間がかかる。
    def fill_scouts(count)
      now = Time.current

      user_ids = User.insert_all!(
        Array.new(count) do |index|
          { email_address: "filler#{index}@example.com", password_digest: "x", confirmed_at: now,
            created_at: now, updated_at: now }
        end
      ).rows.flatten

      profile_ids = CandidateProfile.insert_all!(
        user_ids.map.with_index do |user_id, index|
          { user_id: user_id, display_name: "候補者 #{index}", visibility: "all_organizations",
            scout_opt_in: true, created_at: now, updated_at: now }
        end
      ).rows.flatten

      Scout.insert_all!(
        profile_ids.map do |profile_id|
          { organization_id: @organization.id, candidate_profile_id: profile_id, body: "本文",
            created_at: now, updated_at: now }
        end
      )
    end
end
