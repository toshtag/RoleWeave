require "test_helper"

# 一覧の画面が、件数に比例して問い合わせを増やさないことを検証する。
#
# N+1 は「動くが遅い」欠陥である。画面は正しく表示されるため、
# 通常のテストでは気付けない。
# 詳細は docs/decisions/0049-query-observability.md を参照する。
class QueryCountTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct horse battery".freeze

  setup do
    @candidate = User.create!(email_address: "candidate@example.com", password: PASSWORD).tap(&:confirm)
    @candidate_profile = @candidate.create_candidate_profile!(display_name: "山田 太郎")

    @owner = User.create!(email_address: "owner@example.com", password: PASSWORD).tap(&:confirm)
    @organization = Organization.create_with_owner!(name: "サンプル株式会社", user: @owner)
  end

  test "公開求人の一覧は件数に比例して問い合わせを増やさない" do
    3.times { |index| published_job_posting(title: "求人 #{index}") }
    baseline = count_queries { get public_job_postings_path(locale: :ja) }

    5.times { |index| published_job_posting(title: "追加の求人 #{index}") }
    after = count_queries { get public_job_postings_path(locale: :ja) }

    assert_equal baseline, after, "求人が増えると問い合わせも増えている（N+1）"
  end

  test "応募の一覧は件数に比例して問い合わせを増やさない" do
    job_posting = published_job_posting
    sign_in_as(@owner)
    2.times { |index| applicant(index).job_applications.create!(job_posting: job_posting) }
    baseline = count_queries { get applications_path(job_posting) }

    3.times { |index| applicant(index + 10).job_applications.create!(job_posting: job_posting) }
    after = count_queries { get applications_path(job_posting) }

    assert_equal baseline, after, "応募が増えると問い合わせも増えている（N+1）"
  end

  test "やり取りは件数に比例して問い合わせを増やさない" do
    job_posting = published_job_posting
    application = @candidate_profile.job_applications.create!(job_posting: job_posting)
    conversation = Conversation.create!(job_application: application)
    sign_in_as(@candidate)

    2.times { |index| conversation.messages.create!(sender: @owner, body: "#{index} 通目") }
    baseline = count_queries { get application_conversation_path(locale: :ja, application_id: application) }

    3.times { |index| conversation.messages.create!(sender: @owner, body: "追加 #{index}") }
    after = count_queries { get application_conversation_path(locale: :ja, application_id: application) }

    # 既読の記録は未読の数だけ増える。読み出しの問い合わせが増えないことを見る。
    assert_operator after, :<=, baseline + 3, "メッセージが増えると読み出しの問い合わせも増えている（N+1）"
  end

  test "通知の一覧は件数に比例して問い合わせを増やさない" do
    sign_in_as(@candidate)
    2.times { Notification.create!(user: @candidate, kind: "stage_changed") }
    baseline = count_queries { get notifications_path(locale: :ja) }

    3.times { Notification.create!(user: @candidate, kind: "stage_changed") }
    after = count_queries { get notifications_path(locale: :ja) }

    assert_equal baseline, after, "通知が増えると問い合わせも増えている（N+1）"
  end

  test "候補者の検索の一覧は件数に比例して問い合わせを増やさない" do
    sign_in_as(@owner)
    2.times { |index| searchable_profile(index) }
    baseline = count_queries { get organization_candidate_searches_path(locale: :ja, organization_id: @organization) }

    3.times { |index| searchable_profile(index + 10) }
    after = count_queries { get organization_candidate_searches_path(locale: :ja, organization_id: @organization) }

    assert_equal baseline, after, "候補者が増えると問い合わせも増えている（N+1）"
  end

  test "Webhook の一覧は配信先の数に比例して問い合わせを増やさない" do
    sign_in_as(@owner)
    2.times { |index| webhook_with_delivery(index) }
    baseline = count_queries { get organization_webhooks_path(locale: :ja, organization_id: @organization) }

    3.times { |index| webhook_with_delivery(index + 10) }
    after = count_queries { get organization_webhooks_path(locale: :ja, organization_id: @organization) }

    assert_equal baseline, after, "配信先が増えると問い合わせも増えている（N+1）"
  end

  test "Webhook の一覧は配信の記録を全件読まない" do
    # 問い合わせの数では検出できない。preload は 1 回であり、
    # その 1 回が何行読むかが問題である。読んだ行数で見る。
    sign_in_as(@owner)
    webhook = webhook_with_delivery(0)
    baseline = count_loaded(WebhookDelivery) { get organization_webhooks_path(locale: :ja, organization_id: @organization) }

    5.times { webhook.webhook_deliveries.create!(event_kind: "job_application_created") }
    after = count_loaded(WebhookDelivery) { get organization_webhooks_path(locale: :ja, organization_id: @organization) }

    assert_equal baseline, after, "配信の記録が増えると読み込む行も増えている"
  end

  test "応募の一覧は記録の変更者の数に比例して問い合わせを増やさない" do
    job_posting = published_job_posting
    sign_in_as(@owner)
    # 変更者を持つ記録で作る。持たない記録（kind: created）では
    # belongs_to が問い合わせないため、includes を外しても検出できない。
    2.times { |index| stage_change_event(job_posting, index) }
    baseline = count_queries { get applications_path(job_posting) }

    3.times { |index| stage_change_event(job_posting, index + 10) }
    after = count_queries { get applications_path(job_posting) }

    assert_equal baseline, after, "記録が増えると問い合わせも増えている（N+1）"
  end

  test "公開求人の一覧は、同じ絞り込みを 2 回までしか実行しない" do
    # 1 ページ分を読むのに要るのは、総件数と、そのページの求人の 2 回である。
    # Last-Modified のためにもう一度走らせると、キーワードの絞り込みでは
    # 全件走査が 3 回になる。
    3.times { |index| published_job_posting(title: "求人 #{index}") }

    statements = captured_sql { get public_job_postings_path(locale: :ja, keyword: "求人") }

    assert_equal 2, statements.count { |sql| sql.include?('FROM "job_postings"') },
                 "求人を引く問い合わせが 2 回を超えている:\n#{statements.join("\n")}"
  end

  test "sitemap は求人を 1 回だけ、使う列だけ読む" do
    3.times { |index| published_job_posting(title: "求人 #{index}") }

    statements = captured_sql { get sitemap_path }
    job_posting_statements = statements.select { |sql| sql.include?('FROM "job_postings"') }

    assert_equal 1, job_posting_statements.size,
                 "求人を引く問い合わせが 1 回を超えている:\n#{job_posting_statements.join("\n")}"

    # View が使うのは id と updated_at だけである。
    # description は必須の text であり、本文が長い運用では読んで捨てる量が効く。
    #
    # 読む列を列挙して確かめる。「description を読んでいない」を否定形で書くと、
    # SELECT "job_postings".* を素通りさせる（列名が文へ現れない）。
    assert_match(/SELECT "job_postings"\."id", "job_postings"\."updated_at" FROM/,
                 job_posting_statements.first,
                 "View で使わない列を読んでいる: #{job_posting_statements.first}")
  end

  test "数える補助が実際に数えている" do
    # 補助そのものが 0 を返し続けると、どのテストも通ってしまう。
    assert_operator count_queries { User.count }, :>=, 1
  end

  test "SQL を集める補助が実際に集めている" do
    statements = captured_sql { User.limit(1).to_a }

    assert(statements.any? { |sql| sql.include?('FROM "users"') }, "SQL が集まっていない")
  end

  test "行を数える補助が実際に数えている" do
    # 同じ理由による。0 を返し続ける補助は、何も守らない。
    assert_equal 2, count_loaded(User) { User.limit(2).to_a }
    assert_equal 0, count_loaded(User) { Organization.count }
  end

  private
    # あるモデルが読み込んだ行の数。
    #
    # 問い合わせの数だけでは、1 回で全件を読む形を検出できない。
    # 「使わない行を読んでいないか」は、行の数でしか見えない。
    def count_loaded(model)
      count = 0

      subscriber = ActiveSupport::Notifications.subscribe("instantiation.active_record") do |*args|
        payload = ActiveSupport::Notifications::Event.new(*args).payload

        count += payload[:record_count] if payload[:class_name] == model.name
      end

      yield

      count
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end

    # 実行された SQL の文。
    #
    # 数だけでは「どの表を何回引いたか」「どの列を読んだか」が分からない。
    # 値（bind）は Rails が文へ埋めないため、ここにも現れない（ADR 0049）。
    def captured_sql
      statements = []

      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
        payload = ActiveSupport::Notifications::Event.new(*args).payload

        next if SlowQueryLogger::IGNORED_NAMES.include?(payload[:name])

        statements << payload[:sql]
      end

      yield

      statements
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end

    def sign_in_as(user)
      post session_path(locale: :ja), params: { email_address: user.email_address, password: PASSWORD }
    end

    def published_job_posting(title: "サンプルの求人")
      @organization.job_postings.create!(
        title: title, description: "仕事の内容", status: "published"
      )
    end

    def applicant(index)
      user = User.create!(email_address: "applicant#{index}@example.com", password: PASSWORD).tap(&:confirm)

      user.create_candidate_profile!(display_name: "応募者 #{index}")
    end

    def applications_path(job_posting)
      organization_job_posting_applications_path(
        locale: :ja, organization_id: @organization, job_posting_id: job_posting
      )
    end

    # 検索に出る候補者。スキルを持たせる。一覧がスキルを並べるためである。
    def searchable_profile(index)
      user = User.create!(email_address: "searchable#{index}@example.com", password: PASSWORD).tap(&:confirm)
      profile = user.create_candidate_profile!(
        display_name: "候補者 #{index}", visibility: "all_organizations", scout_opt_in: true
      )
      profile.skills.create!(name: "スキル #{index}")

      profile
    end

    def webhook_with_delivery(index)
      webhook = @organization.webhooks.create!(
        url: "https://example.invalid/hook/#{index}", event_kinds: [ "job_application_created" ]
      )
      webhook.webhook_deliveries.create!(event_kind: "job_application_created")

      webhook
    end

    # 変更者を持つ記録。ステージの変更だけがこれを持つ。
    def stage_change_event(job_posting, index)
      changed_by = User.create!(email_address: "changer#{index}@example.com", password: PASSWORD).tap(&:confirm)

      JobApplicationEvent.create!(
        organization: @organization, job_posting: job_posting, changed_by: changed_by,
        kind: "stage_changed", from_stage: "screening", to_stage: "interviewing",
        candidate_display_name: "応募者 #{index}", job_posting_title: job_posting.title
      )
    end
end
