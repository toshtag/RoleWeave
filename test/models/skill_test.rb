require "test_helper"

# スキルの契約を検証する。
#
# 検証対象は、名前の重複と経験年数の規則である。
class SkillTest < ActiveSupport::TestCase
  setup do
    user = User.create!(email_address: "member@example.com", password: "correct horse battery")
    @candidate_profile = user.create_candidate_profile!(display_name: "山田 太郎")
  end

  test "名前を持つスキルを作成できる" do
    assert_predicate build, :valid?
  end

  test "名前の前後の空白を取り除く" do
    assert_equal "Ruby", build(name: "  Ruby ").name
  end

  test "名前のないスキルを作れない" do
    assert_not build(name: nil).valid?
    assert_not build(name: "   ").valid?
  end

  test "上限を超える名前を拒否する" do
    assert_not build(name: "a" * (Skill::NAME_MAX_LENGTH + 1)).valid?
  end

  test "経験年数は未入力でよい" do
    # 書けない・書きたくない場合がある。
    assert_predicate build(years_of_experience: nil), :valid?
  end

  test "負の経験年数を拒否する" do
    assert_not build(years_of_experience: -1).valid?
  end

  test "整数でない経験年数を拒否する" do
    assert_not build(years_of_experience: 1.5).valid?
  end

  test "人が働ける長さを超える経験年数を拒否する" do
    assert_equal 80, Skill::MAX_YEARS_OF_EXPERIENCE
    assert_predicate build(years_of_experience: Skill::MAX_YEARS_OF_EXPERIENCE), :valid?
    assert_not build(years_of_experience: Skill::MAX_YEARS_OF_EXPERIENCE + 1).valid?
  end

  test "同じプロフィールに同じ名前のスキルを 2 つ作れない" do
    # 同じスキルが 2 つ並ぶと、読み手はどちらが正しいか判断できない。
    build.save!

    assert_not build.valid?
  end

  test "検証を迂回した重複をデータベースが拒否する" do
    build.save!

    assert_raises(ActiveRecord::RecordNotUnique) do
      Skill.insert_all!([ {
        candidate_profile_id: @candidate_profile.id,
        name: "Ruby",
        created_at: Time.current,
        updated_at: Time.current
      } ])
    end
  end

  test "別のプロフィールであれば同じ名前のスキルを作れる" do
    build.save!
    other_user = User.create!(email_address: "other@example.com", password: "correct horse battery")
    other_profile = other_user.create_candidate_profile!(display_name: "他人の名前")

    assert_predicate Skill.new(candidate_profile: other_profile, name: "Ruby"), :valid?
  end

  test "一覧は名前の昇順に並ぶ" do
    ruby = build(name: "Ruby").tap(&:save!)
    docker = build(name: "Docker").tap(&:save!)

    assert_equal [ docker, ruby ], @candidate_profile.skills.alphabetical.to_a
  end

  test "プロフィールを削除するとスキルも消える" do
    build.save!

    assert_difference -> { Skill.count }, -1 do
      @candidate_profile.destroy
    end
  end

  test "所属先のプロフィールを後から付け替えられない" do
    skill = build.tap(&:save!)
    other_user = User.create!(email_address: "other@example.com", password: "correct horse battery")
    other_profile = other_user.create_candidate_profile!(display_name: "他人の名前")

    assert_raises(ActiveRecord::ReadonlyAttributeError) do
      skill.update!(candidate_profile_id: other_profile.id)
    end
  end

  private
    def build(overrides = {})
      Skill.new({ candidate_profile: @candidate_profile, name: "Ruby" }.merge(overrides))
    end
end
