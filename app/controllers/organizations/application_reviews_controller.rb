# 応募への評価とコメントを記録する経路。
#
# 読み書きできるのは、その組織の所属者だけとする。
# 応募者側からは、この経路も内容も見えない。
# 方針は docs/decisions/0039-application-review-and-assignment.md を正本とする。
class Organizations::ApplicationReviewsController < ApplicationController
  include OrganizationScope

  before_action :require_authentication
  before_action :require_confirmed_email
  before_action :set_organization
  before_action :set_job_application

  def create
    @application_review = @job_application.application_reviews.build(
      application_review_params.merge(reviewer: current_user)
    )

    flash[:alert] = t(".invalid") unless @application_review.save

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

    def application_review_params
      params.expect(application_review: %i[rating comment])
    end
end
