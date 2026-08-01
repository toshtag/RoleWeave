# 求職者が求人へ応募する経路。
#
# 応募元は常にログインしている本人のプロフィールとする。
# 方針は docs/decisions/0034-job-application.md を正本とする。
class JobApplicationsController < ApplicationController
  include CandidateProfileScope

  before_action :set_job_posting

  # 応募の確認。何を出すことになるかを先に示す。
  def new
    @job_application = @candidate_profile.job_applications.build(job_posting: @job_posting)
  end

  def create
    @job_application = @candidate_profile.job_applications.build(job_posting: @job_posting)

    if @job_application.save
      redirect_to public_job_posting_path(locale: I18n.locale, id: @job_posting)
    else
      render :new, status: :unprocessable_content
    end
  end

  private
    # 公開中でない求人は、存在しない求人と同じ 404 とする。
    def set_job_posting
      @job_posting = JobPosting.published.find(params[:public_job_posting_id])
    end
end
