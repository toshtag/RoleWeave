require "test_helper"
require "tmpdir"

# 例外応答のロケール解決の契約を検証する。
#
# 検証対象は「元の URL からどのロケールを選ぶか」と「そのロケールを外へ残さないか」であり、
# エラー画面の文言や見た目ではない。実際のページを期待値に使うと、文言の変更でこのテストが壊れる。
# 一時ディレクトリへ識別できるだけの内容を置き、どのファイルが選ばれたかだけを見る。
class LocalizedPublicExceptionsTest < ActiveSupport::TestCase
  PAGES = {
    "404.html" => "DEFAULT 404",
    "404.en.html" => "ENGLISH 404",
    "500.html" => "DEFAULT 500",
    "500.en.html" => "ENGLISH 500"
  }.freeze

  setup do
    @public_path = Dir.mktmpdir("localized-public-exceptions")
    PAGES.each { |name, body| File.write(File.join(@public_path, name), body) }
  end

  teardown do
    FileUtils.remove_entry(@public_path)
  end

  test "英語の URL で英語のページを選ぶ" do
    response = call(original_path: "/en/missing")

    assert_equal "ENGLISH 404", response[:body]
  end

  test "既定ロケールの URL で拡張子を持たないページを選ぶ" do
    # 日本語は既定ロケールのため 404.ja.html を作らない。
    # 同じ HTML を 2 つのファイルで持つと、片方だけが更新される。
    response = call(original_path: "/ja/missing")

    assert_equal "DEFAULT 404", response[:body]
  end

  test "ロケールを持たない URL で既定のページを選ぶ" do
    response = call(original_path: "/missing")

    assert_equal "DEFAULT 404", response[:body]
  end

  test "対応していないロケールで既定のページを選ぶ" do
    # 対応外のロケールを英語へ落とすと、日本語を既定とする設定と矛盾する。
    response = call(original_path: "/fr/missing")

    assert_equal "DEFAULT 404", response[:body]
  end

  test "元のパスが空でも既定のページを選ぶ" do
    # ShowExceptions を経由しない呼び出しでは original_path が存在しない。
    response = call(original_path: nil)

    assert_equal "DEFAULT 404", response[:body]
  end

  test "先頭以外に現れるロケール名をロケールとして扱わない" do
    # パス全体を探すと、/ja/en-training のような日本語の URL が英語になる。
    response = call(original_path: "/ja/en")

    assert_equal "DEFAULT 404", response[:body]
  end

  test "呼び出しの後にロケールを残さない" do
    # 直接代入すると、同じスレッドを使う次のリクエストへエラー画面の言語が漏れる。
    I18n.with_locale(:en) do
      response = call(original_path: "/ja/missing")

      assert_equal "DEFAULT 404", response[:body]
      assert_equal :en, I18n.locale, "呼び出しの後にロケールが書き換わっている"
    end
  end

  test "HTML 以外を要求した応答を HTML へ置き換えない" do
    # 形式の判断は PublicExceptions が持つ。ここで HTML を強制すると、
    # API 呼び出しへ HTML のエラー画面が返る。
    response = call(original_path: "/en/missing", headers: { "HTTP_ACCEPT" => "application/json" })

    assert_match %r{\Aapplication/json}, content_type(response)
    assert_equal 404, JSON.parse(response[:body]).fetch("status")
  end

  test "404 以外の status も同じ規則で解決する" do
    # status ごとに分岐すると、500 だけロケールが効かない状態を作り得る。
    assert_equal "ENGLISH 500", call(original_path: "/en/failure", status: 500)[:body]
    assert_equal "DEFAULT 500", call(original_path: "/ja/failure", status: 500)[:body]
  end

  test "status と Content-Type を PublicExceptions の結果のまま返す" do
    response = call(original_path: "/en/failure", status: 500)

    assert_equal 500, response[:status]
    assert_match %r{\Atext/html}, content_type(response)
  end

  private
    # ShowExceptions が書き換えた後の env を模して呼び出す。
    # PATH_INFO は status だけを持ち、ロケールは original_path にしか残っていない。
    def call(original_path:, status: 404, headers: {})
      env = Rack::MockRequest.env_for("/#{status}", { "HTTP_ACCEPT" => "text/html" }.merge(headers))
      env["action_dispatch.original_path"] = original_path

      response_status, response_headers, body = exceptions_app.call(env)
      content = body.each.to_a.join
      body.close if body.respond_to?(:close)

      { status: response_status, headers: response_headers, body: content }
    end

    # 対応ロケールと既定ロケールをコンストラクターから受け取ることを、
    # 引数を明示して固定する。実装が I18n の設定を直接読むと、ここで検出できない。
    def exceptions_app
      LocalizedPublicExceptions.new(
        public_path: @public_path,
        available_locales: %i[ja en],
        default_locale: :ja
      )
    end

    def content_type(response)
      response[:headers][Rack::CONTENT_TYPE].to_s
    end
end
