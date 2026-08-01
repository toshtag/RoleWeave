require "test_helper"

# 遅い問い合わせの記録の契約を検証する。
#
# 検証対象は、しきい値の扱いと、値（bind）が出ないことである。
class SlowQueryLoggerTest < ActiveSupport::TestCase
  test "しきい値が定数として 1 か所にある" do
    # 値そのものを書く。定数を参照するだけのテストは、緩めたときに一緒に緩む。
    assert_equal 100, SlowQueryLogger::THRESHOLD_MS
  end

  test "しきい値を超えた問い合わせを記録する" do
    output = capture_slow_queries(threshold_ms: 0) { User.count }

    assert_not_empty output, "しきい値を超えた問い合わせが記録されていない"

    entry = JSON.parse(output.first)

    assert_equal "slow_query", entry["event"]
    assert_operator entry["duration_ms"], :>=, 0
    assert_match(/SELECT/i, entry["sql"])
  end

  test "しきい値未満の問い合わせは記録しない" do
    output = capture_slow_queries(threshold_ms: 60_000) { User.count }

    assert_empty output
  end

  test "接続の維持や暗黙の問い合わせは対象にしない" do
    assert_includes SlowQueryLogger::IGNORED_NAMES, "SCHEMA"
    assert_includes SlowQueryLogger::IGNORED_NAMES, "TRANSACTION"
  end

  test "値（bind）が記録に含まれない" do
    # 個人情報が入りうる。
    User.create!(email_address: "secret@example.com", password: "correct horse battery")

    output = capture_slow_queries(threshold_ms: 0) do
      User.where(email_address: "secret@example.com").to_a
    end

    output.each { |line| assert_no_match(/secret@example\.com/, line) }
  end

  private
    # 実装そのものを呼ぶ。同じ判定をテストへ写すと、
    # 実装側の判定を外しても気付けない。
    def capture_slow_queries(threshold_ms:)
      buffer = StringIO.new
      subscriber = SlowQueryLogger.subscribe(logger: ActiveSupport::Logger.new(buffer),
                                             threshold_ms: threshold_ms)

      yield

      buffer.string.lines.select { |line| line.include?("slow_query") }
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end
end
