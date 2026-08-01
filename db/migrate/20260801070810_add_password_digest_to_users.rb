class AddPasswordDigestToUsers < ActiveRecord::Migration[8.1]
  def change
    # bcrypt が生成する文字列。ソルトと反復回数を値の中に含む。
    # 平文は保存しない。詳細は docs/decisions/0006-password-storage-and-policy.md を参照する。
    #
    # パスワードを持たないアカウントを作れる状態にしない。
    # 外部認証は P2 の非目標であり、認証手段のないアカウントに用途がない。
    add_column :users, :password_digest, :string, null: false
  end
end
