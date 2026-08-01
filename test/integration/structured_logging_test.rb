require "test_helper"

# 構造化ログが実際に出ることを検証する。
#
# 組み立てだけを確かめても、出力されていなければ意味がない。
class StructuredLoggingTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct horse battery".freeze

  test "要求の完了が 1 行の JSON として出る" do
    entry = capture_structured_log { get localized_root_path(locale: :ja) }

    assert_equal "request", entry["event"]
    assert_equal "HomeController", entry["controller"]
    assert_equal 200, entry["status"]
    assert_operator entry["duration_ms"], :>=, 0
  end

  test "ログインしていると利用者の id が出る" do
    user = User.create!(email_address: "member@example.com", password: PASSWORD).tap(&:confirm)
    post session_path(locale: :ja), params: { email_address: user.email_address, password: PASSWORD }

    entry = capture_structured_log { get account_path(locale: :ja) }

    assert_equal user.id, entry["user_id"]
  end

  test "ログにメールアドレスが出ない" do
    user = User.create!(email_address: "member@example.com", password: PASSWORD).tap(&:confirm)

    output = capture_log do
      post session_path(locale: :ja), params: { email_address: user.email_address, password: PASSWORD }
    end

    structured = output.lines.select { |line| line.include?("\"event\":\"request\"") }

    assert_not_empty structured
    structured.each { |line| assert_no_match(/member@example\.com/, line) }
  end

  private
    # 構造化ログの行だけを取り出す。
    def capture_structured_log(&block)
      line = capture_log(&block).lines.find { |candidate| candidate.include?("\"event\":\"request\"") }

      assert_not_nil line, "構造化ログが出ていない"

      JSON.parse(line[/\{.*\}/])
    end

    def capture_log
      original = Rails.logger
      buffer = StringIO.new
      Rails.logger = ActiveSupport::Logger.new(buffer)
      # 購読は初期化時に登録されており、そのときの logger を握っている。
      # 出力先を差し替えるため、購読し直す。
      StructuredLogSubscriber.subscribe(logger: Rails.logger)

      yield

      buffer.string
    ensure
      Rails.logger = original
    end
end
