require "test_helper"

# 求人の契約を検証する。
#
# 検証対象は、値の規則と組織との結び付きである。
# 誰が作れるかは integration のテストが持つ。
class JobPostingTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(name: "Example Inc.")
  end

  test "題名と仕事内容を持つ求人を作成できる" do
    assert_predicate build, :valid?
  end

  test "題名の前後の空白を取り除く" do
    assert_equal "採用担当", build(title: "  採用担当 ").title
  end

  test "題名のない求人を作れない" do
    assert_not build(title: nil).valid?
    assert_not build(title: "   ").valid?
  end

  test "上限を超える題名を拒否する" do
    assert_not build(title: "a" * (JobPosting::TITLE_MAX_LENGTH + 1)).valid?
  end

  test "仕事内容のない求人を作れない" do
    assert_not build(description: nil).valid?
  end

  test "決められた状態だけを受け付ける" do
    JobPosting::STATUSES.each do |status|
      assert_predicate build(status: status), :valid?
    end

    assert_not build(status: "unknown").valid?
  end

  test "決められた雇用形態だけを受け付ける" do
    # 自由記述にすると、公開側の絞り込みで表記のゆれを吸収することになる。
    JobPosting::EMPLOYMENT_TYPES.each do |type|
      assert_predicate build(employment_type: type), :valid?
    end

    assert_not build(employment_type: "unknown").valid?
  end

  test "雇用形態は未指定でもよい" do
    assert_predicate build(employment_type: nil), :valid?
    assert_predicate build(employment_type: ""), :valid?
  end

  test "所属先の組織を作成後に変更できない" do
    # 変えられると、自分の組織の求人を他組織へ付け替えられる。
    job_posting = build.tap(&:save!)
    other = Organization.create!(name: "Another Inc.")

    assert_raises(ActiveRecord::ReadonlyAttributeError) do
      job_posting.update!(organization_id: other.id)
    end
  end

  test "組織を削除すると求人も消える" do
    build.save!

    assert_difference -> { JobPosting.count }, -1 do
      @organization.destroy
    end
  end

  test "新しい順に並べられる" do
    older = build(title: "古い求人").tap(&:save!)
    newer = build(title: "新しい求人").tap(&:save!)
    older.update_column(:created_at, 1.day.ago)

    assert_equal [ newer, older ], @organization.job_postings.recent.to_a
  end

  private
    def build(overrides = {})
      @organization.job_postings.new(
        { status: "draft", title: "採用担当", description: "採用の実務を担当します。" }.merge(overrides)
      )
    end
end
