# 求人の公開状態を変える経路。
#
# 編集とは別の resource として置く。同じ経路にすると、
# 編集の権限がそのまま公開の権限になる。
class JobPostingReviewsController < ApplicationController
  include OrganizationScope

  before_action :require_authentication
  before_action :require_confirmed_email
  before_action :set_organization
  before_action :set_job_posting
  # 承認と差し戻しは管理者だけができる。申請は所属者であれば行える。
  # 停止も公開と同じ重さの操作とする。
  before_action :require_organization_owner, only: %i[approve reject suspend]

  def submit
    change_status_to("pending_review")
  end

  def approve
    change_status_to("published")
  end

  def reject
    change_status_to("rejected")
  end

  def suspend
    change_status_to("suspended")
  end

  private
    def set_job_posting
      @job_posting = @organization.job_postings.find(params[:job_posting_id])
    end

    def change_status_to(next_status)
      # 許されていない遷移は、その求人の一覧へ戻して知らせる。
      unless @job_posting.transition_to(next_status)
        flash[:alert] = t("job_postings.review.rejected_transition")
      end

      redirect_to organization_job_postings_path(locale: I18n.locale, organization_id: @organization)
    end
end
