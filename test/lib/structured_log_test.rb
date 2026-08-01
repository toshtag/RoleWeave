require "test_helper"

# 構造化ログの契約を検証する。
#
# 検証対象は、キーが英語であることと、個人情報が出ないことである。
class StructuredLogTest < ActiveSupport::TestCase
  # キーはすべて英語の snake_case とする。識別子は英語で書く。
  ENGLISH_SNAKE_CASE = /\A[a-z][a-z0-9_]*\z/

  test "要求のログのキーがすべて英語の snake_case である" do
    entry = StructuredLog.request(request_payload)

    entry.each_key do |key|
      assert_match ENGLISH_SNAKE_CASE, key.to_s, "#{key} が英語の snake_case でない"
    end
  end

  test "要求のログに経路・状態・時間が入る" do
    entry = StructuredLog.request(request_payload)

    assert_equal "request", entry[:event]
    assert_equal "PublicJobPostingsController", entry[:controller]
    assert_equal "index", entry[:action]
    assert_equal "GET", entry[:method]
    assert_equal 200, entry[:status]
    assert_equal 12.3, entry[:duration_ms]
    assert_equal 4.6, entry[:db_ms]
  end

  test "ログインしている場合は利用者の id が入る" do
    assert_equal 42, StructuredLog.request(request_payload(user_id: 42))[:user_id]
    assert_not StructuredLog.request(request_payload).key?(:user_id)
  end

  test "個人情報が入らない" do
    # ログは転送も保存もされ、公開範囲の設定が効かない。
    entry = StructuredLog.request(
      request_payload(
        params: { "email_address" => "member@example.com", "keyword" => "秘密の条件" },
        path: "/ja/jobs?keyword=秘密の条件"
      )
    )

    json = entry.to_json

    assert_no_match(/member@example\.com/, json)
    assert_no_match(/秘密の条件/, json)
    assert_equal "/ja/jobs", entry[:path]
  end

  test "例外は種類とメッセージだけが入る" do
    entry = StructuredLog.request(request_payload(status: nil, exception: [ "RuntimeError", "壊れた" ]))

    assert_equal "RuntimeError", entry[:exception]
    assert_equal "壊れた", entry[:exception_message]
    # 状態が取れない場合は 500 として記録する。
    assert_equal 500, entry[:status]
  end

  test "ジョブのログのキーがすべて英語の snake_case である" do
    entry = StructuredLog.job(job_payload, event: "job")

    entry.each_key do |key|
      assert_match ENGLISH_SNAKE_CASE, key.to_s, "#{key} が英語の snake_case でない"
    end
  end

  test "ジョブのログにクラス・キュー・時間が入る" do
    entry = StructuredLog.job(job_payload, event: "job")

    assert_equal "job", entry[:event]
    assert_equal "NotificationEmailJob", entry[:job_class]
    assert_equal "default", entry[:queue]
    assert_equal 3.5, entry[:duration_ms]
  end

  test "ジョブの例外は種類とメッセージだけが入る" do
    entry = StructuredLog.job(job_payload(exception_object: IOError.new("送信できない")), event: "job")

    assert_equal "IOError", entry[:exception]
    assert_equal "送信できない", entry[:exception_message]
  end

  test "値のない項目は出さない" do
    # 空の項目が並ぶと、機械で読むときに意味のない分岐が増える。
    entry = StructuredLog.request(request_payload)

    assert_not entry.key?(:exception)
    assert_not entry.key?(:exception_message)
  end

  private
    def request_payload(overrides = {})
      {
        controller: "PublicJobPostingsController",
        action: "index",
        method: "GET",
        path: "/ja/jobs",
        status: 200,
        duration: 12.34,
        db_runtime: 4.56,
        view_runtime: 6.78
      }.merge(overrides)
    end

    def job_payload(overrides = {})
      { job: NotificationEmailJob.new, duration: 3.45 }.merge(overrides)
    end
end
