# 保持期限の確認と適用。
#
# 自動実行はしない。何をいつ消すかは運用の判断であり、
# 気付かないうちに消えている状態を作らない。
# 方針は docs/decisions/0046-data-retention.md を正本とする。
namespace :roleweave do
  namespace :retention do
    desc "保持期限を過ぎたデータの件数を表示する（何も変えない）"
    task report: :environment do
      DataRetention.new.report.each do |table, count|
        policy = DataRetention::POLICIES.fetch(table)

        puts "#{table}: #{count} 件（#{policy.fetch(:period).inspect} を超過 / #{policy.fetch(:strategy)}）"
      end
    end

    desc "保持期限を過ぎたデータを削除または匿名化する"
    task apply: :environment do
      DataRetention.new.apply.each do |table, count|
        policy = DataRetention::POLICIES.fetch(table)

        puts "#{table}: #{count} 件を#{policy.fetch(:strategy) == :delete ? "削除" : "匿名化"}した"
      end
    end
  end
end
