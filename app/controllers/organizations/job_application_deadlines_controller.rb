# 応募の結論の期限を決める経路。
#
# 期限がないと、応募は返事のないまま放置される。
# 方針は docs/decisions/0040-interview-schedule-and-deadline.md を正本とする。
class Organizations::JobApplicationDeadlinesController < ApplicationController
  include OrganizationScope

  before_action :require_authentication
  before_action :require_confirmed_email
  before_action :set_organization
  before_action :set_job_application

  def update
    # 空文字は「期限を外す」を意味する。
    @job_application.decide_by = params[:decide_by].presence

    flash[:alert] = t(".invalid") unless @job_application.save

    redirect_to organization_job_posting_application_path(
      locale: I18n.locale, organization_id: @organization,
      job_posting_id: @job_posting, id: @job_application
    )
  end

  private
    def set_job_application
      @job_posting = @organization.job_postings.find(params[:job_posting_id])
      @job_application = @job_posting.job_applications.find(params[:application_id])
    end
end
