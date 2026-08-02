class AddIndexesForGrowingTables < ActiveRecord::Migration[8.1]
  def change
    # 保持期限（ADR 0046）は created_at だけで対象を選ぶ。
    #
    # 4 つの表のどれにも created_at を先頭に持つ索引がなかった。
    # 複合索引の先頭は user_id や organization_id であり、
    # created_at だけの絞り込みには使えない。
    # 容量モデルは access_events を 3,000 万行、notifications を 1,500 万行と
    # 見積もっている。期限を回すたびに、その全体を走査していた。
    add_index :sessions, :created_at
    add_index :notifications, :created_at
    add_index :access_events, :created_at
    add_index :authentication_events, :created_at

    # ヘッダーの未読の件数は、ログイン中のすべての画面で実行される。
    #
    # (user_id, created_at) の索引は user_id で絞れるが、
    # read_at IS NULL は索引に含まれないため、その利用者の通知を
    # すべて読んでから本体を確かめることになる。
    #
    # 部分索引にするのは、読み終えた通知が対象から外れるためである。
    # 全体へ張ると、保持期限（180 日）の分だけ索引も大きくなる。
    add_index :notifications, :user_id, where: "read_at IS NULL",
              name: "index_notifications_on_user_id_unread"
  end
end
