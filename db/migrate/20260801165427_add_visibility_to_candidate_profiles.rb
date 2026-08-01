class AddVisibilityToCandidateProfiles < ActiveRecord::Migration[8.1]
  def change
    # 既定は closed とする。設定しなければ誰にも見えない。
    # 既存のプロフィールにも既定値が入り、公開範囲を決めないまま見えることがない。
    # 詳細は docs/decisions/0030-profile-visibility.md を参照する。
    add_column :candidate_profiles, :visibility, :string, null: false, default: "closed"

    # 希望年収は応募先との交渉の材料である。ほかの項目とは別に決める。
    add_column :candidate_profiles, :desired_salary_visible, :boolean, null: false, default: false

    # 企業から見えるプロフィールを引くための索引。
    add_index :candidate_profiles, :visibility
  end
end
