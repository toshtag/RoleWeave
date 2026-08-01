class CreateMembershipEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :membership_events do |t|
      # 対象の組織とアカウント。どちらも削除されても記録は残す。
      # 「いつからその人が管理者だったか」は後から復元できない。
      # 詳細は docs/decisions/0014-membership-change-history.md を参照する。
      t.references :organization, null: true, foreign_key: { on_delete: :nullify }
      t.references :user, null: true, foreign_key: { on_delete: :nullify }

      # 変更した主体。招待の受諾のように主体が本人の場合は本人を記録する。
      t.references :changed_by, null: true, foreign_key: { to_table: :users, on_delete: :nullify }

      # 出来事の種類。取り得る値は MembershipEvent が持つ。
      t.string :kind, null: false

      # 変更前と変更後の役割。追加のときは変更前を持たない。
      t.string :from_role
      t.string :to_role, null: false

      t.timestamps
    end

    # 調査は「この組織の直近」から始まる。
    add_index :membership_events, [ :organization_id, :created_at ]
  end
end
