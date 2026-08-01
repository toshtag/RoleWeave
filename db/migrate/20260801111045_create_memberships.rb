class CreateMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :memberships do |t|
      # 所属は組織とアカウントの両方へ従属する。どちらが消えても残さない。
      t.references :organization, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      # 組織の中での役割。取り得る値は Membership が持つ。
      t.string :role, null: false

      t.timestamps
    end

    # 同じアカウントを同じ組織へ 2 度所属させない。
    # 検証だけでは、同時に届いた 2 つの追加の間で重複を防げない。
    add_index :memberships, [ :organization_id, :user_id ], unique: true
  end
end
