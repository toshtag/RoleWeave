require "test_helper"

# 並行して送ったときに、1 日の上限を超えないことを検証する。
#
# 検証対象は、**数えてから保存するまでの間に別の送信が入れないこと**である。
# ここが緩むと、上限そのものを書いてあっても超えられる。
class ScoutConcurrencyTest < ActiveSupport::TestCase
  # 同時に走らせる数。接続の数（RAILS_MAX_THREADS の既定は 5）に収める。
  THREADS = 3

  # 別の接続から同じ行を見る必要がある。
  # テストのトランザクションの中で作ると、他の接続からは見えない。
  self.use_transactional_tests = false

  PASSWORD = "correct horse battery".freeze

  setup do
    recruiter = User.create!(email_address: "recruiter@example.com", password: PASSWORD).tap(&:confirm)
    @organization = Organization.create_with_owner!(name: "サンプル株式会社", user: recruiter)
  end

  # トランザクションを使わないため、作った行が次のテストへ残る。
  teardown do
    ActiveRecord::Base.connection_pool.with_connection do |connection|
      connection.truncate_tables(*(connection.tables - %w[schema_migrations ar_internal_metadata]))
    end
  end

  test "残りが 1 件のときに並行して送っても、上限を超えない" do
    fill_scouts(limit - 1)

    results = send_in_parallel(create_profiles(THREADS))

    assert_equal 1, results.count(true)
    assert_equal limit, @organization.scouts.count
  end

  test "残りの数だけは並行しても成功する" do
    fill_scouts(limit - THREADS)

    results = send_in_parallel(create_profiles(THREADS))

    assert_equal THREADS, results.count(true)
    assert_equal limit, @organization.scouts.count
  end

  test "拒否された送信は行を残さない" do
    fill_scouts(limit - 1)
    profiles = create_profiles(THREADS)

    send_in_parallel(profiles)

    rejected = profiles.reject { |profile| @organization.scouts.exists?(candidate_profile: profile) }

    assert_equal THREADS - 1, rejected.size
    assert_equal 0, Notification.where(kind: "scout_received").count
  end

  test "別の組織は独立した上限を持つ" do
    fill_scouts(limit)
    outsider = User.create!(email_address: "outsider@example.com", password: PASSWORD).tap(&:confirm)
    other = Organization.create_with_owner!(name: "別の会社", user: outsider)
    profile = create_profiles(1).sole

    assert other.scouts.build(candidate_profile: profile, body: "本文").save_within_daily_limit
  end

  private
    # 天井を置く。定数を緩める変異を入れたときに、巨大なデータを作りに行かないようにする。
    def limit
      [ Scout::DAILY_LIMIT_PER_ORGANIZATION, 60 ].min
    end

    def send_in_parallel(profiles)
      barrier = Concurrent::CyclicBarrier.new(profiles.size)

      profiles.map do |profile|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            # 組織は thread ごとに読み直す。`with_lock` は行を読み直すため、
            # 同じ instance を共有すると thread の間で状態を奪い合う。
            scout = Organization.find(@organization.id)
                                .scouts.build(candidate_profile: profile, body: "本文")
            # 数える前に足並みをそろえる。ここをそろえないと、
            # たまたま直列に走って上限を超えないことがある。
            barrier.wait
            scout.save_within_daily_limit
          end
        end
      end.map(&:value)
    end

    def create_profiles(count)
      now = Time.current

      user_ids = User.insert_all!(
        Array.new(count) do |index|
          { email_address: "candidate#{index}@example.com", password_digest: "x", confirmed_at: now,
            created_at: now, updated_at: now }
        end
      ).rows.flatten

      CandidateProfile.where(
        id: CandidateProfile.insert_all!(
          user_ids.map.with_index do |user_id, index|
            { user_id: user_id, display_name: "候補者 #{index}", visibility: "all_organizations",
              scout_opt_in: true, created_at: now, updated_at: now }
          end
        ).rows.flatten
      ).to_a
    end

    # 上限の直前まで埋める。1 件ずつ作ると、パスワードの計算だけで時間がかかる。
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
          { user_id: user_id, display_name: "埋め草 #{index}", visibility: "all_organizations",
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
