# ログイン状態を表すレコード。
#
# ブラウザーへ渡すのは、このレコードの ID を署名付き Cookie へ入れたものだけとする。
# アカウント ID を直接 Cookie へ入れる方式では、サーバー側からログイン状態を無効にできない。
# 方針は docs/decisions/0007-database-backed-sessions.md を正本とする。
class Session < ApplicationRecord
  # 無操作でログイン状態を保つ上限。
  # 共有端末でログアウトを忘れたときに、そのまま次の利用者が操作できる時間を区切る。
  IDLE_TIMEOUT = 14.days

  # 発行からの上限。無操作の上限だけでは、使い続けている限り期限が来ない。
  # 盗まれた Cookie を、いつか必ず無効にするための上限とする。
  ABSOLUTE_TIMEOUT = 90.days

  # 最終利用時刻を書き込む間隔。
  # リクエストのたびに更新すると、読み出しだけの操作でも毎回書き込みが起こる。
  # 無操作の判定は日単位のため、1 時間の粗さで足りる。
  ACTIVITY_UPDATE_INTERVAL = 1.hour

  belongs_to :user

  before_validation :start_activity, on: :create

  def expired?
    last_active_at <= IDLE_TIMEOUT.ago || created_at <= ABSOLUTE_TIMEOUT.ago
  end

  # Cookie を残す期間。発行からの上限に合わせる。
  # ブラウザー側に、サーバーがすでに無効とみなす Cookie を持たせ続けない。
  def cookie_expires_at
    created_at + ABSOLUTE_TIMEOUT
  end

  # 最終利用時刻を進める。間隔を空けて書き込み、読み出しだけの操作で毎回書かない。
  def touch_activity
    return if last_active_at > ACTIVITY_UPDATE_INTERVAL.ago

    update_column(:last_active_at, Time.current)
  end

  private
    def start_activity
      self.last_active_at ||= Time.current
    end
end
