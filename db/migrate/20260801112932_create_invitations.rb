class CreateInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :invitations do |t|
      # 招待は組織へ従属する。組織が消えたら残さない。
      t.references :organization, null: false, foreign_key: true

      # 宛先はメールアドレスとする。アカウントへ結び付けない。
      # 招待した時点で相手のアカウントが存在しないことがある。
      # 詳細は docs/decisions/0012-organization-invitations.md を参照する。
      t.string :email_address, null: false

      # 受諾したときに与える役割。取り得る値は Membership が持つ。
      t.string :role, null: false

      # 招待した人。アカウントが消えても招待の事実は残す。
      t.references :invited_by, null: true, foreign_key: { to_table: :users, on_delete: :nullify }

      # 受諾した時刻。未受諾は NULL で表す。
      t.datetime :accepted_at

      t.timestamps
    end

    # 未受諾の招待は、同じ組織・同じ宛先で 1 件までとする。
    # 受諾済みは対象にしない。同じ人を抜けた後に招待し直せる必要がある。
    add_index :invitations,
              [ :organization_id, :email_address ],
              unique: true,
              where: "accepted_at IS NULL",
              name: "index_pending_invitations_on_organization_and_email"
  end
end
