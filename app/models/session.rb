# ログイン状態を表すレコード。
#
# ブラウザーへ渡すのは、このレコードの ID を署名付き Cookie へ入れたものだけとする。
# アカウント ID を直接 Cookie へ入れる方式では、サーバー側からログイン状態を無効にできない。
# 方針は docs/decisions/0007-database-backed-sessions.md を正本とする。
class Session < ApplicationRecord
  belongs_to :user
end
