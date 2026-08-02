require "test_helper"

# 受け取る入力の大きさの契約を検証する。
#
# 検証対象は、上限を超えた本文が本体へ届かないことと、
# 上限までの本文がいままでどおり通ることである。
class RequestSizeLimitTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct horse battery".freeze

  HEADER = JobPostingCsv::COLUMNS.join(",").freeze

  setup do
    @owner = User.create!(email_address: "owner@example.com", password: PASSWORD).tap(&:confirm)
    @organization = Organization.create_with_owner!(name: "サンプル株式会社", user: @owner)
  end

  test "上限を超える本文が 413 になる" do
    status, _headers, body = limiter.call(env_with_length(RequestBodyLimit::MAX_BYTES + 1))

    assert_equal 413, status
    assert_match(/413/, body.first)
  end

  test "上限までの本文は通る" do
    status, = limiter.call(env_with_length(RequestBodyLimit::MAX_BYTES))

    assert_equal 200, status
  end

  test "本文を持たない要求は通る" do
    status, = limiter.call(env_with_length(nil))

    assert_equal 200, status
  end

  test "413 の応答を日本語と英語で返す" do
    _status, _headers, japanese = limiter.call(env_with_length(RequestBodyLimit::MAX_BYTES + 1, path: "/ja/jobs"))
    _status, _headers, english = limiter.call(env_with_length(RequestBodyLimit::MAX_BYTES + 1, path: "/en/jobs"))

    assert_match(/lang="ja"/, japanese.first)
    assert_match(/lang="en"/, english.first)
  end

  test "上限を超える本文は本体へ届かない" do
    # 気付いた時点ですでに受け取っている、という状態にしない。
    reached = false
    app = ->(_env) { reached = true }

    RequestBodyLimit.new(app).call(env_with_length(RequestBodyLimit::MAX_BYTES + 1))

    assert_not reached
  end

  test "上限を超える CSV は取り込まない" do
    sign_in_as(@owner)
    oversized = "#{HEADER}\n#{"key-1,題名,#{"あ" * 1_000},,,,,,,\n" * 2_000}"

    assert_operator oversized.bytesize, :>, JobPostingCsv::MAX_BYTE_SIZE

    assert_no_difference -> { JobPosting.count } do
      post imports_path, params: { file: uploaded(oversized) }
    end

    assert_match(/#{JobPostingCsv::MAX_ROWS}/, flash[:alert])
  end

  test "行数の上限を超える CSV は 1 件も取り込まない" do
    # 取り込みながら止めると、半分だけ入った状態が残る。
    sign_in_as(@owner)
    rows = (JobPostingCsv::MAX_ROWS + 1).times.map { |index| "key-#{index},題名,本文,,,,,,," }

    assert_no_difference -> { JobPosting.count } do
      post imports_path, params: { file: uploaded("#{HEADER}\n#{rows.join("\n")}\n") }
    end
  end

  test "上限内の CSV はいままでどおり取り込める" do
    sign_in_as(@owner)

    assert_difference -> { JobPosting.count }, 1 do
      post imports_path, params: { file: uploaded("#{HEADER}\nkey-1,題名,本文,,,,,,,\n") }
    end
  end

  test "ファイルでない値を送っても 500 にならない" do
    sign_in_as(@owner)

    post imports_path, params: { file: "ファイルではない文字列" }

    assert_redirected_to new_organization_job_posting_import_path(locale: :ja,
                                                                  organization_id: @organization)
    assert_equal I18n.t("organizations.job_posting_imports.create.missing_file"), flash[:alert]
  end

  private
    def limiter(app = ->(_env) { [ 200, {}, [ "ok" ] ] })
      RequestBodyLimit.new(app)
    end

    def env_with_length(length, path: "/ja/jobs")
      { "PATH_INFO" => path, "REQUEST_METHOD" => "POST" }.tap do |env|
        env["CONTENT_LENGTH"] = length.to_s if length
      end
    end

    def sign_in_as(user)
      post session_path(locale: :ja), params: { email_address: user.email_address, password: PASSWORD }
    end

    def imports_path
      organization_job_posting_imports_path(locale: :ja, organization_id: @organization)
    end

    def uploaded(body)
      Rack::Test::UploadedFile.new(StringIO.new(body), "text/csv", original_filename: "job_postings.csv")
    end
end
