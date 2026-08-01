require "test_helper"

# 組織へ従属するデータの、組織との結び付きの契約を検証する。
#
# 個々のモデルではなく「組織へ従属するモデルすべて」を対象にする。
# 1 つずつ書くと、新しいモデルが増えたときに書き忘れが穴になる。
class OrganizationScopingTest < ActiveSupport::TestCase
  # 検査から外すモデル。外す場合は、外してよい理由をここへ書く。
  # 現時点で外すものはない。
  EXCLUDED = [].freeze

  test "組織へ従属するモデルが 1 つ以上ある" do
    # 対象が 0 件のまま「すべて満たしている」と報告しない。
    assert_operator organization_scoped_models.size, :>=, 2
  end

  test "組織へ従属するモデルは所属先を作成後に変更できない" do
    # 変えられると、自分の組織のレコードを他組織へ付け替えられる。
    organization_scoped_models.each do |model|
      assert_includes model.readonly_attributes, "organization_id",
        "#{model.name} の organization_id が変更できる"
    end
  end

  test "組織へ従属するモデルは組織を必須とする" do
    organization_scoped_models.each do |model|
      association = model.reflect_on_association(:organization)

      assert_not association.options[:optional],
        "#{model.name} が組織を持たないレコードを許している"
    end
  end

  test "組織を削除すると従属するデータも消える" do
    # 残すと、参照先のないデータが他組織の集計や検索へ紛れ込みうる。
    organization_scoped_models.each do |model|
      association = Organization.reflect_on_all_associations(:has_many)
                                .find { |candidate| candidate.klass == model }

      assert association, "Organization から #{model.name} への has_many がない"
      assert_equal :destroy, association.options[:dependent],
        "Organization から #{model.name} が削除時に残る"
    end
  end

  test "組織に属する resource が組織の下以外の route を持たない" do
    # 組織の外に route があると、その経路だけ OrganizationScope を通らない。
    scoped_controllers = %w[memberships invitations]

    Rails.application.routes.routes.each do |route|
      controller = route.defaults[:controller]
      next unless scoped_controllers.include?(controller)

      # 招待の受諾は token で対象を決めるため、組織の下には置かない。
      next if controller == "invitations" && route.defaults[:action] == "show"

      assert_includes route.path.spec.to_s, ":organization_id",
        "#{controller}##{route.defaults[:action]} が組織の下にない"
    end
  end

  private
    # 組織へ従属するモデル。belongs_to :organization を持つものを対象にする。
    def organization_scoped_models
      @organization_scoped_models ||= begin
        Rails.application.eager_load!

        ApplicationRecord.descendants.select do |model|
          next false if EXCLUDED.include?(model.name)

          model.reflect_on_association(:organization)&.belongs_to?
        end
      end
    end
end
