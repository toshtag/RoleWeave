class AddConfirmedAtToUsers < ActiveRecord::Migration[8.1]
  def change
    # メールアドレスを確認した時刻。未確認は NULL で表す。
    #
    # 真偽値ではなく時刻を持つ。いつ確認したかは、後から問い合わせへ答えるときに要る。
    # 詳細は docs/decisions/0008-email-confirmation.md を参照する。
    add_column :users, :confirmed_at, :datetime
  end
end
