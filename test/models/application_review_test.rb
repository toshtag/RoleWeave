require "test_helper"

# 応募への評価と担当者の契約を検証する。
#
# 検証対象は、値の規則と、応募者側へ漏れないことである。
class ApplicationReviewTest < ActiveSupport::TestCase
  PASSWORD = "correct horse battery".freeze

  setup do
    candidate = User.create!(email_address: "candidate@example.com", password: PASSWORD).tap(&:confirm)
    @candidate_profile = candidate.create_candidate_profile!(display_name: "山田 太郎")

    @owner = User.create!(email_address: "owner@example.com", password: PASSWORD).tap(&:confirm)
    @organization = Organization.create_with_owner!(name: "サンプル株式会社", user: @owner)
    @job_posting = @organization.job_postings.create!(
      title: "サンプルの求人", description: "仕事の内容", status: "published"
    )
    @job_application = @candidate_profile.job_applications.create!(job_posting: @job_posting)
  end

  test "評価とコメントを記録できる" do
    assert_predicate build(rating: 4, comment: "良い経歴だった"), :valid?
  end

  test "評価だけ、コメントだけでも記録できる" do
    assert_predicate build(rating: 4, comment: nil), :valid?
    assert_predicate build(rating: nil, comment: "コメントだけ"), :valid?
  end

  test "両方が空の記録を作れない" do
    # 何も伝えていない。
    assert_not build(rating: nil, comment: nil).valid?
    assert_not build(rating: nil, comment: "   ").valid?
  end

  test "評価は 1 から 5 の整数に限る" do
    assert_equal 1, ApplicationReview::MIN_RATING
    assert_equal 5, ApplicationReview::MAX_RATING
    assert_predicate build(rating: 1), :valid?
    assert_predicate build(rating: 5), :valid?
    assert_not build(rating: 0).valid?
    assert_not build(rating: 6).valid?
    assert_not build(rating: 3.5).valid?
  end

  test "1 つの応募に複数の評価を残せる" do
    # 選考の段階ごとに見る人が違う。
    build(rating: 4).save!
    build(rating: 2, comment: "別の担当者の見方").save!

    assert_equal 2, @job_application.application_reviews.count
  end

  test "記録した人を削除しても記録は残る" do
    another_owner = User.create!(email_address: "owner2@example.com", password: PASSWORD)
    @organization.memberships.create!(user: another_owner, role: "owner", changed_by: @owner)
    build(rating: 4, reviewer: @owner).save!

    assert_no_difference -> { ApplicationReview.count } do
      AccountDeletion.new(@owner).delete!
    end

    assert_nil ApplicationReview.sole.reviewer
    assert_equal 4, ApplicationReview.sole.rating
  end

  test "記録の内容を後から書き換えられない" do
    review = build(rating: 4).tap(&:save!)

    assert_raises(ActiveRecord::ReadonlyAttributeError) { review.update!(rating: 1) }
  end

  test "応募を削除すると評価も消える" do
    build(rating: 4).save!

    assert_difference -> { ApplicationReview.count }, -1 do
      @job_application.destroy
    end
  end

  test "評価は応募の写しに含まれない" do
    # 応募者には見せない情報である。
    build(rating: 1, comment: "内部の評価").save!

    snapshot = @job_application.reload.candidate_profile_snapshot.to_json

    assert_no_match(/内部の評価/, snapshot)
  end

  test "評価はエクスポートに含まれない" do
    build(rating: 1, comment: "内部の評価").save!

    assert_no_match(/内部の評価/, ProfileExport.new(@candidate_profile.user).to_json)
  end

  test "担当者は組織の所属者に限る" do
    outsider = User.create!(email_address: "outsider@example.com", password: PASSWORD)

    @job_application.assignee = outsider

    assert_not @job_application.valid?
  end

  test "所属者を担当者にできる" do
    @job_application.assignee = @owner

    assert_predicate @job_application, :valid?
  end

  test "担当者を外せる" do
    @job_application.update!(assignee: @owner)

    assert @job_application.update(assignee: nil)
  end

  private
    def build(overrides = {})
      @job_application.application_reviews.build(
        { reviewer: @owner, rating: 3, comment: nil }.merge(overrides)
      )
    end
end
