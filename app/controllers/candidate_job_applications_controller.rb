# 求職者が自分の応募を確認し、取り消す経路。
#
# 対象は常に本人のプロフィールに属する応募とする。
# 一覧と詳細は、現在の求人ではなく応募時点の写しを出す（ADR 0034）。
# 方針は docs/decisions/0035-application-withdrawal.md を正本とする。
class CandidateJobApplicationsController < ApplicationController
  include CandidateProfileScope

  before_action :set_job_application, only: %i[show destroy]

  def index
    @job_applications = @candidate_profile.job_applications.includes(:job_posting).recent
  end

  def show
  end

  # 取消。記録は残し、状態だけを変える。
  def destroy
    @job_application.withdraw

    redirect_to profile_applications_path(locale: I18n.locale)
  end

  private
    # 本人のプロフィールを起点に引く。
    # `JobApplication.find` にすると、他人の応募も引けてしまう。
    def set_job_application
      @job_application = @candidate_profile.job_applications.find(params[:id])
    end
end
