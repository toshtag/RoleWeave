require "test_helper"

# 公開ページのキャッシュの契約を検証する。
#
# 検証対象は、条件付き GET が効くことと、
# 共有キャッシュへ載せてよい応答とそうでない応答の区別である。
class PublicPageCachingTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct horse battery".freeze

  setup do
    owner = User.create!(email_address: "owner@example.com", password: PASSWORD)
    owner.confirm
    @owner = owner
    @organization = Organization.create_with_owner!(name: "Example Inc.", user: owner)
    @published = create_job_posting(title: "公開中の求人")
  end

  test "一覧が ETag と Last-Modified を返す" do
    get public_job_postings_path(locale: :ja)

    assert_response :success
    assert response.headers["ETag"].present?, "ETag がない"
    assert response.headers["Last-Modified"].present?, "Last-Modified がない"
  end

  test "内容が変わっていなければ一覧は 304 を返す" do
    get public_job_postings_path(locale: :ja)
    etag = response.headers["ETag"]

    get public_job_postings_path(locale: :ja), headers: { "If-None-Match" => etag }

    assert_response :not_modified
  end

  test "求人が増えると一覧は 304 を返さない" do
    get public_job_postings_path(locale: :ja)
    etag = response.headers["ETag"]

    create_job_posting(title: "新しい求人")

    get public_job_postings_path(locale: :ja), headers: { "If-None-Match" => etag }

    assert_response :success
  end

  test "求人が更新されると一覧は 304 を返さない" do
    get public_job_postings_path(locale: :ja)
    etag = response.headers["ETag"]

    @published.update!(title: "書き換えた求人")

    get public_job_postings_path(locale: :ja), headers: { "If-None-Match" => etag }

    assert_response :success
  end

  test "絞り込みの条件が変わると 304 を返さない" do
    get public_job_postings_path(locale: :ja)
    etag = response.headers["ETag"]

    get public_job_postings_path(locale: :ja, keyword: "公開"), headers: { "If-None-Match" => etag }

    assert_response :success
  end

  test "ログイン状態が変わると 304 を返さない" do
    # レイアウトのヘッダーがログイン状態で変わる。
    get public_job_postings_path(locale: :ja)
    etag = response.headers["ETag"]

    post session_path(locale: :ja), params: { email_address: @owner.email_address, password: PASSWORD }

    get public_job_postings_path(locale: :ja), headers: { "If-None-Match" => etag }

    assert_response :success
  end

  test "別のページにしか出ない求人を更新しても、1 ページ目の Last-Modified が進まない" do
    # Last-Modified は、そのページに出る求人から作る（ADR 0025）。
    # 絞り込み結果の全体から作ると、2 ページ目の更新で 1 ページ目の
    # Last-Modified が進み、内容が変わっていないページに 200 が返る。
    Pagination::DEFAULT_PER_PAGE.times { |index| create_job_posting(title: "求人 #{index}") }

    get public_job_postings_path(locale: :ja)
    first_page_last_modified = response.headers["Last-Modified"]

    # 1 ページ目に出ない求人（最も古い＝2 ページ目）を更新する。
    travel 1.hour do
      @published.update!(title: "書き換えた求人")
    end

    get public_job_postings_path(locale: :ja)

    assert_equal first_page_last_modified, response.headers["Last-Modified"],
                 "1 ページ目に出ない求人の更新で Last-Modified が進んでいる"
  end

  test "sitemap が ETag と Last-Modified を返す" do
    get sitemap_path

    assert_response :success
    assert response.headers["ETag"].present?, "ETag がない"
    assert response.headers["Last-Modified"].present?, "Last-Modified がない"
  end

  test "sitemap も条件付き GET が効く" do
    get sitemap_path
    etag = response.headers["ETag"]

    get sitemap_path, headers: { "If-None-Match" => etag }

    assert_response :not_modified
    assert_empty response.body, "304 なのに本文を送っている"
  end

  test "求人が更新されると sitemap は 304 を返さない" do
    get sitemap_path
    etag = response.headers["ETag"]

    @published.update!(title: "書き換えた求人")

    get sitemap_path, headers: { "If-None-Match" => etag }

    assert_response :success
    assert_match(/<urlset/, response.body)
  end

  test "robots も条件付き GET で壊れない" do
    # robots は fresh_when を呼ばない。ETag は Rack が付ける。
    # sitemap と同じ壊れ方をしないことを、こちらでも押さえておく。
    get robots_path
    etag = response.headers["ETag"]

    get robots_path, headers: { "If-None-Match" => etag }

    assert_response :not_modified
  end

  test "詳細も条件付き GET が効く" do
    get public_job_posting_path(locale: :ja, id: @published)
    etag = response.headers["ETag"]

    get public_job_posting_path(locale: :ja, id: @published), headers: { "If-None-Match" => etag }

    assert_response :not_modified

    @published.update!(title: "書き換えた求人")

    get public_job_posting_path(locale: :ja, id: @published), headers: { "If-None-Match" => etag }

    assert_response :success
  end

  test "公開求人の応答を共有キャッシュへ載せない" do
    # 応答がログイン状態で変わるため、共有キャッシュへ載せられない。
    [ public_job_postings_path(locale: :ja), public_job_posting_path(locale: :ja, id: @published) ].each do |path|
      get path

      assert_includes response.headers["Cache-Control"].to_s, "private", "#{path} が private でない"
    end
  end

  test "sitemap と robots は共有キャッシュへ載せてよい" do
    # どちらもログイン状態に依存しない。
    [ sitemap_path, robots_path ].each do |path|
      get path

      cache_control = response.headers["Cache-Control"].to_s

      assert_includes cache_control, "public", "#{path} が public でない"
      assert_match(/max-age=\d+/, cache_control, "#{path} に max-age がない")
    end
  end

  private
    def create_job_posting(title:)
      @organization.job_postings.create!(status: "published", title: title, description: "内容")
    end
end
