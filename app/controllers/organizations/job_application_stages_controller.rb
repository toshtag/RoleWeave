# 選考ステージを進める経路。
#
# 応募を見る経路とは分けて置く。同じ経路にすると、
# 見る権限がそのまま選考を動かす権限になる（ADR 0017 と同じ理由）。
# 方針は docs/decisions/0038-selection-stage.md を正本とする。
class Organizations::JobApplicationStagesController < ApplicationController
  include OrganizationScope

  before_action :require_authentication
  before_action :require_confirmed_email
  before_action :set_organization
  before_action :set_job_application
  before_action :set_next_stage
  # 確定（内定・採用・不採用・辞退）は管理者だけができる。
  before_action :require_organization_owner, if: -> { JobApplication.owner_only_stage?(@next_stage) }

  def update
    unless @job_application.move_to(@next_stage, changed_by: current_user)
      flash[:alert] = t(".invalid_transition")
    end

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

    # 進める先は決まった値だけを受け取る。
    # 受け取った文字列をそのまま渡すと、定めていない状態へ書き換えられる。
    def set_next_stage
      @next_stage = JobApplication::STAGES.find { |stage| stage == params[:stage] }

      raise ActiveRecord::RecordNotFound if @next_stage.nil?
    end
end
