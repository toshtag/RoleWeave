require "test_helper"

# 学歴の契約を検証する。
#
# 期間の規則は HasPeriod が持つ。ここでは学歴としての規則を確かめる。
class EducationTest < ActiveSupport::TestCase
  setup do
    user = User.create!(email_address: "member@example.com", password: "correct horse battery")
    @candidate_profile = user.create_candidate_profile!(display_name: "山田 太郎")
  end

  test "学校名と入学日を持つ学歴を作成できる" do
    assert_predicate build, :valid?
  end

  test "学校名の前後の空白を取り除く" do
    assert_equal "サンプル大学", build(school_name: "  サンプル大学 ").school_name
  end

  test "学校名のない学歴を作れない" do
    assert_not build(school_name: nil).valid?
    assert_not build(school_name: "   ").valid?
  end

  test "入学日のない学歴を作れない" do
    assert_not build(started_on: nil).valid?
  end

  test "専攻と学位は未入力でよい" do
    assert_predicate build(field_of_study: nil, degree: nil), :valid?
  end

  test "上限を超える項目を拒否する" do
    assert_not build(school_name: "a" * (Education::SCHOOL_NAME_MAX_LENGTH + 1)).valid?
    assert_not build(field_of_study: "a" * (Education::FIELD_OF_STUDY_MAX_LENGTH + 1)).valid?
    assert_not build(degree: "a" * (Education::DEGREE_MAX_LENGTH + 1)).valid?
  end

  test "卒業日のない学歴は在学中として扱う" do
    assert_predicate build(ended_on: nil), :current?
  end

  test "プロフィールを削除すると学歴も消える" do
    build.save!

    assert_difference -> { Education.count }, -1 do
      @candidate_profile.destroy
    end
  end

  test "所属先のプロフィールを後から付け替えられない" do
    education = build.tap(&:save!)
    other_user = User.create!(email_address: "other@example.com", password: "correct horse battery")
    other_profile = other_user.create_candidate_profile!(display_name: "他人の名前")

    assert_raises(ActiveRecord::ReadonlyAttributeError) do
      education.update!(candidate_profile_id: other_profile.id)
    end
  end

  private
    def build(overrides = {})
      Education.new({
        candidate_profile: @candidate_profile,
        school_name: "サンプル大学",
        started_on: Date.new(2016, 4, 1)
      }.merge(overrides))
    end
end
