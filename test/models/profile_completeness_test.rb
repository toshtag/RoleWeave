require "test_helper"

# 応募に必要な項目の確認の契約を検証する。
#
# 検証対象は、何をそろっていると数えるかである。
class ProfileCompletenessTest < ActiveSupport::TestCase
  setup do
    user = User.create!(email_address: "member@example.com", password: "correct horse battery")
    @candidate_profile = user.create_candidate_profile!(display_name: "山田 太郎")
  end

  test "作ったばかりのプロフィールはすべての項目がそろっていない" do
    assert_equal ProfileCompleteness::ITEMS, completeness.missing_items
    assert_not_predicate completeness, :complete?
  end

  test "自己紹介を書くとその項目が外れる" do
    @candidate_profile.update!(introduction: "採用の実務を担当してきました。")

    assert_not_includes completeness.missing_items, :introduction
  end

  test "職歴・学歴・スキルを 1 件でも登録するとその項目が外れる" do
    @candidate_profile.work_experiences.create!(
      organization_name: "株式会社サンプル", position: "人事", started_on: Date.new(2020, 4, 1)
    )
    @candidate_profile.educations.create!(school_name: "サンプル大学", started_on: Date.new(2016, 4, 1))
    @candidate_profile.skills.create!(name: "Ruby")

    assert_equal [ :introduction, :desired_condition ], completeness.missing_items
  end

  test "中身のない希望条件はそろっていると数えない" do
    # 保存しただけで数えると、何も書かれていない希望条件がそろったことになる。
    @candidate_profile.create_desired_condition!

    assert_includes completeness.missing_items, :desired_condition
  end

  test "希望条件を 1 つでも書くとその項目が外れる" do
    @candidate_profile.create_desired_condition!(location: "東京")

    assert_not_includes completeness.missing_items, :desired_condition
  end

  test "すべて書くとそろったと数える" do
    fill_everything

    assert_empty completeness.missing_items
    assert_predicate completeness, :complete?
  end

  test "知らない項目を尋ねられたら止まる" do
    # 綴りの誤りが「そろっていない」として静かに現れるのを避ける。
    assert_raises(ArgumentError) { completeness.filled?(:unknown_item) }
  end

  private
    def completeness
      ProfileCompleteness.new(@candidate_profile.reload)
    end

    def fill_everything
      @candidate_profile.update!(introduction: "採用の実務を担当してきました。")
      @candidate_profile.work_experiences.create!(
        organization_name: "株式会社サンプル", position: "人事", started_on: Date.new(2020, 4, 1)
      )
      @candidate_profile.educations.create!(school_name: "サンプル大学", started_on: Date.new(2016, 4, 1))
      @candidate_profile.skills.create!(name: "Ruby")
      @candidate_profile.create_desired_condition!(employment_type: "full_time")
    end
end
