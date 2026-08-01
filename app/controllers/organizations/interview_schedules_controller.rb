# 面接の予定を扱う経路。
#
# 読み書きできるのは、その組織の所属者だけとする。
# 予定は応募者へは伝わらない。伝える手段は P9 で扱う。
# 方針は docs/decisions/0040-interview-schedule-and-deadline.md を正本とする。
class Organizations::InterviewSchedulesController < ApplicationController
  include OrganizationScope

  before_action :require_authentication
  before_action :require_confirmed_email
  before_action :set_organization
  before_action :set_job_application

  def create
    @interview_schedule = @job_application.interview_schedules.build(
      interview_schedule_params.merge(created_by: current_user)
    )

    flash[:alert] = t(".invalid") unless @interview_schedule.save

    redirect_to_application
  end

  def destroy
    schedule = @job_application.interview_schedules.find(params[:id])

    schedule.cancel

    redirect_to_application
  end

  private
    def set_job_application
      @job_posting = @organization.job_postings.find(params[:job_posting_id])
      @job_application = @job_posting.job_applications.find(params[:application_id])
    end

    def interview_schedule_params
      params.expect(interview_schedule: %i[starts_at duration_minutes location note])
    end

    def redirect_to_application
      redirect_to organization_job_posting_application_path(
        locale: I18n.locale, organization_id: @organization,
        job_posting_id: @job_posting, id: @job_application
      )
    end
end
