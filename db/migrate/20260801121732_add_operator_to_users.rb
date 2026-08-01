class AddOperatorToUsers < ActiveRecord::Migration[8.1]
  def change
    # このサーバーを運用する側かどうか。
    #
    # 画面から付与する経路は作らない。自己ホストの前提では、
    # 運営者は「そのサーバーを運用している人」であり、外部の誰かではない。
    # 詳細は docs/decisions/0015-operator-role.md を参照する。
    add_column :users, :operator, :boolean, null: false, default: false
  end
end
