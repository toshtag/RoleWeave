require "test_helper"

# 応募の契約を検証する。
#
# 検証対象は、二重応募の拒否と、応募時点の写しである。
class JobApplicationTest < ActiveSupport::TestCase
  PASSWORD = "correct horse battery".freeze

  setup do
    candidate = User.create!(email_address: "candidate@example.com", password: PASSWORD).tap(&:confirm)
    @candidate_profile = candidate.create_candidate_profile!(display_name: "山田 太郎")

    recruiter = User.create!(email_address: "recruiter@example.com", password: PASSWORD).tap(&:confirm)
    @organization = Organization.create_with_owner!(name: "サンプル株式会社", user: recruiter)
    @job_posting = published_job_posting
  end

  test "公開中の求人へ応募できる" do
    assert_predicate build, :valid?
  end

  test "応募の状態は submitted で始まる" do
    assert_equal "submitted", build.tap(&:save!).status
  end

  test "公開中でない求人へは応募できない" do
    # まだ募集していない仕事へ応募が届く状態を作らない。
    draft = @organization.job_postings.create!(title: "下書きの求人", description: "本文", status: "draft")

    assert_not build(job_posting: draft).valid?
  end

  test "同じ求人へ 2 回応募できない" do
    build.save!

    assert_not build.valid?
  end

  test "検証を迂回した二重応募をデータベースが拒否する" do
    build.save!

    assert_raises(ActiveRecord::RecordNotUnique) do
      JobApplication.insert_all!([ {
        candidate_profile_id: @candidate_profile.id,
        job_posting_id: @job_posting.id,
        status: "submitted",
        created_at: Time.current,
        updated_at: Time.current
      } ])
    end
  end

  test "別の求人へは応募できる" do
    build.save!
    another = published_job_posting(title: "別の求人")

    assert_predicate build(job_posting: another), :valid?
  end

  test "応募先と応募元を後から付け替えられない" do
    job_application = build.tap(&:save!)
    another = published_job_posting(title: "別の求人")

    assert_raises(ActiveRecord::ReadonlyAttributeError) do
      job_application.update!(job_posting_id: another.id)
    end
  end

  test "応募時点の求人の内容が保存される" do
    snapshot = build.tap(&:save!).job_posting_snapshot

    assert_equal "サンプルの求人", snapshot["title"]
    assert_equal "サンプル株式会社", snapshot["organization_name"]
  end

  test "求人を後から編集しても、保存された内容は変わらない" do
    job_application = build.tap(&:save!)

    @job_posting.update!(title: "書き換えた題名")

    assert_equal "サンプルの求人", job_application.reload.job_posting_snapshot["title"]
  end

  test "応募時点のプロフィールが保存される" do
    @candidate_profile.work_experiences.create!(
      organization_name: "株式会社サンプル", position: "人事", started_on: Date.new(2020, 4, 1)
    )
    @candidate_profile.skills.create!(name: "Ruby")

    snapshot = build.tap(&:save!).candidate_profile_snapshot

    assert_equal "山田 太郎", snapshot["display_name"]
    assert_equal "株式会社サンプル", snapshot["work_experiences"].sole["organization_name"]
    assert_equal "Ruby", snapshot["skills"].sole["name"]
  end

  test "プロフィールを後から変えても、保存された内容は変わらない" do
    job_application = build.tap(&:save!)

    @candidate_profile.update!(display_name: "書き換えた名前")
    @candidate_profile.skills.create!(name: "あとから足したスキル")

    snapshot = job_application.reload.candidate_profile_snapshot

    assert_equal "山田 太郎", snapshot["display_name"]
    assert_empty snapshot["skills"]
  end

  test "希望年収は見せる設定のときだけ保存される" do
    # 応募したことと、希望年収を明かすことは別の判断である。
    @candidate_profile.create_desired_condition!(
      employment_type: "full_time", salary_currency: "JPY", annual_salary_min: 5_000_000
    )

    hidden = build.tap(&:save!).candidate_profile_snapshot["desired_condition"]

    assert_equal "full_time", hidden["employment_type"]
    assert_not hidden.key?("annual_salary_min")

    @candidate_profile.update!(desired_salary_visible: true)
    shown = build(job_posting: published_job_posting(title: "別の求人")).tap(&:save!)
                                                                       .candidate_profile_snapshot["desired_condition"]

    assert_equal 5_000_000, shown["annual_salary_min"]
  end

  test "写しに内部の識別子が入らない" do
    # 別の環境へ移したときに意味を持たず、応募時に何を見たかの説明にもならない。
    job_application = build.tap(&:save!)

    [ job_application.job_posting_snapshot, job_application.candidate_profile_snapshot ].each do |snapshot|
      assert_not snapshot.key?("id")
      assert_not snapshot.key?("organization_id")
      assert_not snapshot.key?("user_id")
      assert_not snapshot.key?("candidate_profile_id")
    end
  end

  test "プロフィールを削除すると応募も消える" do
    build.save!

    assert_difference -> { JobApplication.count }, -1 do
      @candidate_profile.destroy
    end
  end

  private
    def build(overrides = {})
      JobApplication.new({ candidate_profile: @candidate_profile, job_posting: @job_posting }.merge(overrides))
    end

    def published_job_posting(title: "サンプルの求人")
      @organization.job_postings.create!(
        title: title, description: "仕事の内容", location: "東京", occupation: "人事",
        employment_type: "full_time", status: "published"
      )
    end
end
