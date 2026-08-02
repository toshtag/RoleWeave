# 企業がスカウトを送る経路。
#
# 送れるのは探せる候補者だけとする。判定はモデルが持つ。
# 方針は docs/decisions/0056-scouting.md を正本とする。
class Organizations::ScoutsController < ApplicationController
  include OrganizationScope
  include AccessLogging

  before_action :require_authentication
  before_action :require_confirmed_email
  before_action :set_organization

  def index
    @scouts = @organization.scouts.includes(:candidate_profile, :sent_by).recent
    @remaining = Scout::DAILY_LIMIT_PER_ORGANIZATION -
                 @organization.scouts.where(created_at: Time.current.all_day).count
  end

  def new
    # 探せない候補者は、存在しない候補者と同じ 404 とする。
    @candidate_profile = CandidateProfile.searchable.find(params[:candidate_profile_id])
    @scout = @organization.scouts.build(candidate_profile: @candidate_profile)
    @scout_templates = @organization.scout_templates.recent
  end

  def create
    @candidate_profile = CandidateProfile.searchable.find(params[:candidate_profile_id])
    @scout = @organization.scouts.build(
      candidate_profile: @candidate_profile, sent_by: current_user, body: params[:body]
    )

    if @scout.save_within_daily_limit
      notify(@scout)
      record_access("scout_sent", subject: @candidate_profile,
                                  subject_label: @candidate_profile.display_name,
                                  organization: @organization)

      redirect_to organization_scouts_path(locale: I18n.locale, organization_id: @organization)
    else
      flash[:alert] = @scout.errors.full_messages.to_sentence
      @scout_templates = @organization.scout_templates.recent

      render :new, status: :unprocessable_content
    end
  end

  private
    # 受信は通知で知らせる。メールの本文にスカウトの本文は書かない。
    def notify(scout)
      user = scout.candidate_profile.user
      notification = Notification.create!(user: user, kind: "scout_received", scout: scout)

      unless user.email_notifications?
        notification.update_column(:email_status, "skipped")
        return
      end

      NotificationEmailJob.perform_later(notification, locale: I18n.locale)
    end
end
