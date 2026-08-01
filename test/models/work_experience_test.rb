require "test_helper"

# 求職者の職歴の契約を検証する。
#
# 検証対象は、プロフィールとの結び付き、期間の規則、並び順である。
# 誰が扱えるかは integration のテストが持つ。
class WorkExperienceTest < ActiveSupport::TestCase
  setup do
    user = User.create!(email_address: "member@example.com", password: "correct horse battery")
    @candidate_profile = user.create_candidate_profile!(display_name: "山田 太郎")
  end

  test "会社名・役職・開始日を持つ職歴を作成できる" do
    assert_predicate build, :valid?
  end

  test "会社名と役職の前後の空白を取り除く" do
    work_experience = build(organization_name: "  株式会社サンプル ", position: " 人事 ")

    assert_equal "株式会社サンプル", work_experience.organization_name
    assert_equal "人事", work_experience.position
  end

  test "会社名のない職歴を作れない" do
    assert_not build(organization_name: nil).valid?
    assert_not build(organization_name: "   ").valid?
  end

  test "役職のない職歴を作れない" do
    assert_not build(position: nil).valid?
    assert_not build(position: "   ").valid?
  end

  test "開始日のない職歴を作れない" do
    assert_not build(started_on: nil).valid?
  end

  test "上限を超える項目を拒否する" do
    assert_not build(organization_name: "a" * (WorkExperience::ORGANIZATION_NAME_MAX_LENGTH + 1)).valid?
    assert_not build(position: "a" * (WorkExperience::POSITION_MAX_LENGTH + 1)).valid?
    assert_not build(description: "a" * (WorkExperience::DESCRIPTION_MAX_LENGTH + 1)).valid?
  end

  test "終了日のない職歴は在籍中として扱う" do
    # 終了日を必須にすると、在籍中を表せないか、未来の日付を入れることになる。
    work_experience = build(ended_on: nil)

    assert_predicate work_experience, :valid?
    assert_predicate work_experience, :current?
  end

  test "終了日を持つ職歴は在籍中ではない" do
    assert_not build(ended_on: Date.new(2024, 3, 31)).current?
  end

  test "終了日が開始日より前の職歴を拒否する" do
    work_experience = build(started_on: Date.new(2024, 4, 1), ended_on: Date.new(2024, 3, 31))

    assert_not work_experience.valid?
    assert_includes work_experience.errors.attribute_names, :ended_on
  end

  test "開始日と終了日が同じ職歴を受け入れる" do
    # 同じ日に始まり同じ日に終わる在籍もありうる。
    assert_predicate build(started_on: Date.new(2024, 4, 1), ended_on: Date.new(2024, 4, 1)), :valid?
  end

  test "未来の開始日を拒否する" do
    # まだ始まっていない職歴は、応募の時点で語れる経験ではない。
    work_experience = build(started_on: Date.current + 1)

    assert_not work_experience.valid?
    assert_includes work_experience.errors.attribute_names, :started_on
  end

  test "本日の開始日を受け入れる" do
    assert_predicate build(started_on: Date.current), :valid?
  end

  test "一覧は開始日の新しい順に並ぶ" do
    old = build(organization_name: "古い会社", started_on: Date.new(2018, 4, 1)).tap(&:save!)
    recent = build(organization_name: "新しい会社", started_on: Date.new(2022, 4, 1)).tap(&:save!)

    assert_equal [ recent, old ], @candidate_profile.work_experiences.recent.to_a
  end

  test "プロフィールを削除すると職歴も消える" do
    build.save!

    assert_difference -> { WorkExperience.count }, -1 do
      @candidate_profile.destroy
    end
  end

  test "アカウントを削除すると職歴も消える" do
    build.save!

    assert_difference -> { WorkExperience.count }, -1 do
      @candidate_profile.user.destroy
    end
  end

  test "所属先のプロフィールを後から付け替えられない" do
    # 付け替えられると、自分の職歴を他人のプロフィールへ足せる。
    work_experience = build.tap(&:save!)
    other_user = User.create!(email_address: "other@example.com", password: "correct horse battery")
    other_profile = other_user.create_candidate_profile!(display_name: "他人の名前")

    assert_raises(ActiveRecord::ReadonlyAttributeError) do
      work_experience.update!(candidate_profile_id: other_profile.id)
    end
  end

  private
    def build(overrides = {})
      WorkExperience.new({
        candidate_profile: @candidate_profile,
        organization_name: "株式会社サンプル",
        position: "人事",
        started_on: Date.new(2020, 4, 1)
      }.merge(overrides))
    end
end
