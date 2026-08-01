# 手元で再現できる負荷試験。
#
# 外部の負荷ツールを足さない。自己ホストの利用者が、
# このリポジトリだけで同じ手順を踏めるようにする。
# 方針は docs/decisions/0050-capacity-model.md を正本とする。
namespace :roleweave do
  namespace :load do
    desc "負荷試験のデータを作る（求人の件数を指定する）"
    task :seed, [ :job_postings ] => :environment do |_task, args|
      count = (args[:job_postings] || 1_000).to_i

      puts LoadTestData.new.seed(job_postings: count)
    end

    desc "主要な経路の応答時間を測る（回数を指定する）"
    task :measure, [ :iterations ] => :environment do |_task, args|
      iterations = (args[:iterations] || 20).to_i

      LoadTestMeasurement.new(iterations: iterations).run.each do |result|
        puts format("%-34s 状態 %-7s p50 %6.1f ms  p95 %6.1f ms  最大 %6.1f ms  (%d 回)",
                    result[:name], result[:status], result[:p50], result[:p95], result[:max],
                    result[:iterations])
      end

      puts "データ量: #{LoadTestData.new.summary}"
    end

    desc "負荷試験のデータを消す"
    task clean: :environment do
      puts LoadTestData.new.clean
    end
  end
end
