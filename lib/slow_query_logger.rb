# しきい値を超えた SQL を、構造化ログとして出す。
#
# 遅いことが分かっていても、どれが遅いかは測らないと分からない。
# **値（bind）は出さない。**個人情報が入りうる。
# 方針は docs/decisions/0049-query-observability.md を正本とする。
module SlowQueryLogger
  # これを超えた問い合わせを記録する。
  #
  # 100 ミリ秒は「画面の応答として気になり始める」水準として置く。
  # 値そのものに根拠はなく、測った結果に応じて見直す。
  THRESHOLD_MS = 100

  # 記録しない種類。接続の維持や暗黙の問い合わせは対象にしない。
  IGNORED_NAMES = [ "SCHEMA", "TRANSACTION", "CACHE" ].freeze

  def self.subscribe(logger:, threshold_ms: THRESHOLD_MS)
    ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
      event = ActiveSupport::Notifications::Event.new(*args)

      next if IGNORED_NAMES.include?(event.payload[:name])
      next if event.duration < threshold_ms

      logger.warn(StructuredLog.slow_query(event.payload, duration: event.duration).to_json)
    end
  end
end
