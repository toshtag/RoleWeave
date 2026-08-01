require "test_helper"

# 希望条件の契約を検証する。
#
# 検証対象は、求人との語彙の一致と、通貨と金額の組み合わせである。
class DesiredConditionTest < ActiveSupport::TestCase
  setup do
    user = User.create!(email_address: "member@example.com", password: "correct horse battery")
    @candidate_profile = user.create_candidate_profile!(display_name: "山田 太郎")
  end

  test "雇用形態と通貨の語彙が求人と一致する" do
    # 食い違うと、希望と求人を突き合わせられない。
    assert_equal JobPosting::EMPLOYMENT_TYPES, DesiredCondition::EMPLOYMENT_TYPES
    assert_equal JobPosting::SALARY_CURRENCIES, DesiredCondition::SALARY_CURRENCIES
  end

  test "すべて未入力の希望条件を保存できる" do
    # 希望を書かないことも 1 つの状態である。
    assert_predicate build, :valid?
    assert_predicate build, :blank_conditions?
  end

  test "語彙にない雇用形態を拒否する" do
    assert_not build(employment_type: "volunteer").valid?
  end

  test "語彙にない通貨を拒否する" do
    assert_not build(salary_currency: "BTC", annual_salary_min: 5_000_000).valid?
  end

  test "通貨と希望年収の両方を入力した希望条件を保存できる" do
    assert_predicate build(salary_currency: "JPY", annual_salary_min: 5_000_000), :valid?
  end

  test "通貨のない希望年収を拒否する" do
    # 通貨のない金額は読めない。
    assert_not build(annual_salary_min: 5_000_000).valid?
  end

  test "希望年収のない通貨を拒否する" do
    # 金額のない通貨は何も示していない。
    assert_not build(salary_currency: "JPY").valid?
  end

  test "負の希望年収を拒否する" do
    assert_not build(salary_currency: "JPY", annual_salary_min: -1).valid?
  end

  test "整数でない希望年収を拒否する" do
    assert_not build(salary_currency: "JPY", annual_salary_min: 1.5).valid?
  end

  test "0 の希望年収を受け入れる" do
    assert_predicate build(salary_currency: "JPY", annual_salary_min: 0), :valid?
  end

  test "上限を超える項目を拒否する" do
    assert_not build(location: "a" * (DesiredCondition::LOCATION_MAX_LENGTH + 1)).valid?
    assert_not build(note: "a" * (DesiredCondition::NOTE_MAX_LENGTH + 1)).valid?
  end

  test "1 つのプロフィールに 2 つの希望条件を作れない" do
    build.save!

    assert_not build.valid?
  end

  test "検証を迂回した重複をデータベースが拒否する" do
    build.save!

    assert_raises(ActiveRecord::RecordNotUnique) do
      DesiredCondition.insert_all!([ {
        candidate_profile_id: @candidate_profile.id,
        created_at: Time.current,
        updated_at: Time.current
      } ])
    end
  end

  test "何か 1 つでも書かれていれば未入力ではない" do
    assert_not build(location: "東京").blank_conditions?
    assert_not build(note: "週 3 日から").blank_conditions?
    assert_not build(available_from: Date.new(2026, 10, 1)).blank_conditions?
  end

  test "プロフィールを削除すると希望条件も消える" do
    build.save!

    assert_difference -> { DesiredCondition.count }, -1 do
      @candidate_profile.destroy
    end
  end

  test "所属先のプロフィールを後から付け替えられない" do
    desired_condition = build.tap(&:save!)
    other_user = User.create!(email_address: "other@example.com", password: "correct horse battery")
    other_profile = other_user.create_candidate_profile!(display_name: "他人の名前")

    assert_raises(ActiveRecord::ReadonlyAttributeError) do
      desired_condition.update!(candidate_profile_id: other_profile.id)
    end
  end

  private
    def build(overrides = {})
      DesiredCondition.new({ candidate_profile: @candidate_profile }.merge(overrides))
    end
end
