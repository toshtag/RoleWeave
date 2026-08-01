class CreateOrganizations < ActiveRecord::Migration[8.1]
  def change
    create_table :organizations do |t|
      # 表示名。同名の組織は実在するため、一意にはしない。
      # 詳細は docs/decisions/0011-organizations-and-memberships.md を参照する。
      t.string :name, null: false

      t.timestamps
    end
  end
end
