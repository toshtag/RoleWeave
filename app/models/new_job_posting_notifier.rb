# 保存した検索条件に一致する新着の求人を知らせる。
#
# **前回の通知より後に公開された求人だけ**を対象にする。
# 同じ求人を 2 回通知すると、通知そのものが読まれなくなる。
# 方針は docs/decisions/0054-saved-searches.md を正本とする。
class NewJobPostingNotifier
  def initialize(now: Time.current)
    @now = now
  end

  # 通知した件数を、保存した条件ごとに返す。
  def run
    SavedSearch.notifying.includes(candidate_profile: :user).find_each.filter_map do |saved_search|
      count = notify(saved_search)

      next if count.zero?

      [ saved_search.id, count ]
    end.to_h
  end

  private
    def notify(saved_search)
      job_postings = new_job_postings_for(saved_search)

      # 一致がなくても時刻は進める。次回に古い求人が混ざらないようにする。
      saved_search.update_column(:notified_at, @now)

      return 0 if job_postings.empty?

      create_notification(saved_search, job_postings.size)

      job_postings.size
    end

    def new_job_postings_for(saved_search)
      scope = saved_search.matching_job_postings

      # 初回は「保存してから後に公開されたもの」を対象にする。
      since = saved_search.notified_at || saved_search.created_at

      scope.where(updated_at: since...@now).to_a
    end

    def create_notification(saved_search, count)
      user = saved_search.candidate_profile.user

      notification = Notification.create!(
        user: user, kind: "new_job_postings", saved_search: saved_search, new_job_postings_count: count
      )

      unless user.email_notifications?
        notification.update_column(:email_status, "skipped")
        return
      end

      NotificationEmailJob.perform_later(notification, locale: I18n.default_locale)
    end
end
