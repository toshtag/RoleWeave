class CreateAccessEvents < ActiveRecord::Migration[8.1]
  def change
    # 個人情報を読んだ操作の記録。
    #
    # 状態を変えた操作は既存の記録が持つ。読んだことは、どこにも残っていなかった。
    # 詳細は docs/decisions/0047-access-audit-log.md を参照する。
    create_table :access_events do |t|
      # 操作した人。削除しても記録は残す。
      t.references :actor, foreign_key: { to_table: :users, on_delete: :nullify }
      t.references :organization, foreign_key: { on_delete: :nullify }

      t.string :action, null: false
      # 対象の種類と識別子。対象が消えても、何に対する操作かが読める。
      t.string :subject_type, null: false
      t.bigint :subject_id
      t.string :subject_label, null: false

      t.string :ip_address

      t.timestamps
    end

    add_index :access_events, [ :organization_id, :created_at ]
    add_index :access_events, [ :subject_type, :subject_id ]
  end
end
