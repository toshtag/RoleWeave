# 主要な経路の応答時間を測る。
#
# アプリケーションの中（統合セッション）で測る。
# 外部の負荷ツールを足さないためであり、ネットワークの影響も除ける。
# その代わり、実際の配信経路（Puma・リバースプロキシ）の時間は含まれない。
# 方針は docs/decisions/0050-capacity-model.md を正本とする。
class LoadTestMeasurement
  # 対応ブラウザーとして扱われる UA。allow_browser の判定を通すために使う。
  MODERN_USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
                      "(KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36".freeze

  def initialize(iterations: 20)
    @iterations = iterations
    @data = LoadTestData.new
  end

  def run
    job_posting = @data.sample_job_posting

    targets = {
      "公開求人の一覧" => "/ja/jobs",
      "公開求人の一覧（キーワード）" => "/ja/jobs?keyword=%E9%96%8B%E7%99%BA",
      "公開求人の一覧（2 ページ目）" => "/ja/jobs?page=2",
      "公開求人の詳細" => job_posting ? "/ja/jobs/#{job_posting.id}" : nil,
      "トップページ" => "/ja",
      "sitemap.xml" => "/sitemap.xml"
    }.compact

    targets.map { |name, path| measure(name, path) }
  end

  private
    def measure(name, path)
      session = ActionDispatch::Integration::Session.new(Rails.application)
      # 既定の www.example.com は host authorization に弾かれる。
      # 対応外ブラウザーの案内（406）も避けるため、UA を明示する。
      session.host! "localhost"
      durations = []

      statuses = []

      @iterations.times do
        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        session.get(path, headers: { "HTTP_USER_AGENT" => MODERN_USER_AGENT })
        durations << (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1_000
        statuses << session.response.status
      end

      sorted = durations.sort

      {
        name: name,
        iterations: @iterations,
        # 応答の状態も返す。200 以外を測っても、意味のある数字にならない。
        status: statuses.uniq.sort.join(","),
        p50: percentile(sorted, 0.5),
        p95: percentile(sorted, 0.95),
        max: sorted.last
      }
    end

    def percentile(sorted, ratio)
      sorted[(sorted.size * ratio).ceil - 1] || 0.0
    end
end
