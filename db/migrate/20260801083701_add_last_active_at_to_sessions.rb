class AddLastActiveAtToSessions < ActiveRecord::Migration[8.1]
  def change
    # 無操作の判定に使う最終利用時刻。
    #
    # updated_at では代用できない。他の属性を更新したときにも動くため、
    # 「利用者が使った時刻」と「レコードを書き換えた時刻」が混ざる。
    add_column :sessions, :last_active_at, :datetime, null: false
  end
end
