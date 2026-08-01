class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      # アカウントの識別子。値の正規化はモデルが行う。
      # 詳細は docs/decisions/0005-email-address-as-account-identifier.md を参照する。
      t.string :email_address, null: false

      t.timestamps
    end

    # 一意性はデータベースで担保する。
    # モデルの検証だけでは、同時に届いた 2 つの登録の間で重複を防げない。
    add_index :users, :email_address, unique: true
  end
end
