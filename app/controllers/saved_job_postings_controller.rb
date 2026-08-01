# 求職者が求人を保存する経路。
#
# 対象は常に本人のプロフィールとする。
# 方針は docs/decisions/0054-saved-searches.md を正本とする。
class SavedJobPostingsController < ApplicationController
  include CandidateProfileScope

  def index
    @saved_job_postings = @candidate_profile.saved_job_postings.includes(:job_posting).recent
  end

  def create
    # 公開中でない求人は、存在しない求人と同じ 404 とする。
    job_posting = JobPosting.published.find(params[:job_posting_id])
    saved = @candidate_profile.saved_job_postings.build(job_posting: job_posting)

    flash[:alert] = t(".invalid") unless saved.save

    redirect_to public_job_posting_path(locale: I18n.locale, id: job_posting)
  end

  def destroy
    @candidate_profile.saved_job_postings.find(params[:id]).destroy!

    redirect_to profile_saved_jobs_path(locale: I18n.locale)
  end
end
