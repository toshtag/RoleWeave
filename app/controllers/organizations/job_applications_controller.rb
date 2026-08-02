# 企業側が自分の組織の求人へ届いた応募を見る経路。
#
# 対象は所属する組織の求人に届いた応募だけとする。
# 見るのは応募時点の写しであり、現在のプロフィールではない（ADR 0034）。
# 方針は docs/decisions/0036-organization-application-access.md を正本とする。
class Organizations::JobApplicationsController < ApplicationController
  include OrganizationScope
  include AccessLogging

  before_action :require_authentication
  before_action :require_confirmed_email
  before_action :set_organization
  before_action :set_job_posting

  def index
    @job_applications = @job_posting.job_applications.recent

    # 応募そのものが消えても、記録は残る。両方を出す。
    # 変更者は画面に出す。preload しないと、記録の数だけ問い合わせが増える。
    @job_application_events = @job_posting.job_application_events.includes(:changed_by).recent.limit(50)
  end

  def show
    @job_application = @job_posting.job_applications.find(params[:id])

    # 応募の詳細は応募時点の写し（個人情報）である。開いたことを記録する。
    record_access("job_application_viewed",
                  subject: @job_application,
                  subject_label: @job_application.candidate_profile_snapshot["display_name"],
                  organization: @organization)

    # 応募時点の写しとは別に、いまプロフィールを見られるかを判定する。
    # 見られる場合だけ、現在のプロフィールへの導線を出す。
    # 評価とコメントは所属者だけが読む。応募者側からは見えない。
    @application_reviews = @job_application.application_reviews.includes(:reviewer).recent
    @application_review = @job_application.application_reviews.build
    @members = @organization.users.order(:email_address)

    # 面接の予定も社内の情報である。応募者側からは見えない。
    @interview_schedules = @job_application.interview_schedules.upcoming
    @interview_schedule = @job_application.interview_schedules.build

    @candidate_profile = CandidateProfile.visible_to(@organization)
                                         .find_by(id: @job_application.candidate_profile_id)
  end

  private
    # 自組織の求人だけを対象にする。
    # `JobPosting.find` にすると、他組織の求人の応募も引けてしまう。
    def set_job_posting
      @job_posting = @organization.job_postings.find(params[:job_posting_id])
    end
end
