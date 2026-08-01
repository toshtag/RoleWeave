# 保存した検索条件への新着の通知。
#
# 自動実行はしない。いつ通知するかは運用の判断である（ADR 0046 と同じ理由）。
# 方針は docs/decisions/0054-saved-searches.md を正本とする。
namespace :roleweave do
  namespace :sourcing do
    desc "保存した検索条件に一致する新着の求人を通知する"
    task notify_new_job_postings: :environment do
      results = NewJobPostingNotifier.new.run

      if results.empty?
        puts "通知する新着はなかった"
      else
        results.each { |saved_search_id, count| puts "保存した条件 #{saved_search_id}: #{count} 件を通知した" }
      end
    end
  end
end
