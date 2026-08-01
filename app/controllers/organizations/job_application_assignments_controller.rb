# 応募の担当者を決める経路。
#
# 担当者はその組織の所属者に限る。判定はモデルが持つ。
# 方針は docs/decisions/0039-application-review-and-assignment.md を正本とする。
class Organizations::JobApplicationAssignmentsController < ApplicationController
  include OrganizationScope

  before_action :require_authentication
  before_action :require_confirmed_email
  before_action :set_organization
  before_action :set_job_application

  def update
    # 空文字は「担当者を外す」を意味する。
    @job_application.assignee_id = params[:assignee_id].presence

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
