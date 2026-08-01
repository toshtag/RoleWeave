require "test_helper"

# 期間の規則を、それを含むすべてのモデルで検証する。
#
# 規則そのものは 1 か所にある。片方のモデルだけで確かめると、
# 取り込み忘れたモデルが検証されないまま残る。
class HasPeriodTest < ActiveSupport::TestCase
  setup do
    user = User.create!(email_address: "member@example.com", password: "correct horse battery")
    @candidate_profile = user.create_candidate_profile!(display_name: "山田 太郎")
  end

  # 期間を持つモデルと、必須項目を埋めるための値。
  # モデルを足したときは、ここへ足さないと検証されない。
  SUBJECTS = {
    WorkExperience => { organization_name: "株式会社サンプル", position: "人事" },
    Education => { school_name: "サンプル大学" }
  }.freeze

  test "期間を持つモデルがすべて HasPeriod を含む" do
    # 取り込み忘れると、そのモデルだけ規則が効かない状態になる。
    with_period = ApplicationRecord.descendants.select { |model| model.column_names.include?("started_on") }
                                   .select { |model| model.column_names.include?("ended_on") }

    assert_equal SUBJECTS.keys.map(&:name).sort, with_period.map(&:name).sort
  end

  test "終了日のない経歴を作れる" do
    each_subject do |record|
      record.ended_on = nil

      assert_predicate record, :valid?
      assert_predicate record, :current?
    end
  end

  test "終了日が開始日より前の経歴を拒否する" do
    each_subject do |record|
      record.started_on = Date.new(2024, 4, 1)
      record.ended_on = Date.new(2024, 3, 31)

      assert_not record.valid?
      assert_includes record.errors.attribute_names, :ended_on
    end
  end

  test "開始日と同じ終了日を受け入れる" do
    each_subject do |record|
      record.started_on = Date.new(2024, 4, 1)
      record.ended_on = Date.new(2024, 4, 1)

      assert_predicate record, :valid?
    end
  end

  test "未来の開始日を拒否する" do
    each_subject do |record|
      record.started_on = Date.current + 1

      assert_not record.valid?
      assert_includes record.errors.attribute_names, :started_on
    end
  end

  test "開始日のない経歴を拒否する" do
    each_subject do |record|
      record.started_on = nil

      assert_not record.valid?
    end
  end

  test "一覧は開始日の新しい順に並ぶ" do
    SUBJECTS.each do |model, attributes|
      old = create_record(model, attributes, started_on: Date.new(2018, 4, 1))
      recent = create_record(model, attributes, started_on: Date.new(2022, 4, 1))

      assert_equal [ recent, old ], model.recent.to_a, "#{model.name} の並び順"
    end
  end

  private
    def each_subject
      SUBJECTS.each do |model, attributes|
        record = model.new(attributes.merge(
          candidate_profile: @candidate_profile,
          started_on: Date.new(2020, 4, 1)
        ))

        yield record
      end
    end

    def create_record(model, attributes, overrides)
      model.create!(attributes.merge(candidate_profile: @candidate_profile).merge(overrides))
    end
end
