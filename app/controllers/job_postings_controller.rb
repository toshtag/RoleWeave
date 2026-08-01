class JobPostingsController < ApplicationController
  include OrganizationScope

  before_action :require_authentication
  before_action :require_confirmed_email
  before_action :set_organization
  before_action :set_job_posting, only: %i[edit update preview]
  # 編集できるのは下書きと差し戻しだけとする。
  # 申請中と公開中の内容が、審査や公開の後で勝手に変わらないようにする。
  before_action :require_editable, only: %i[edit update]

  def index
    # 自組織の求人だけを出す。対象は set_organization がすでに絞っている。
    @job_postings = @organization.job_postings.recent

    # 履歴は所属者であれば見られる。差し戻された担当者が、
    # いつ差し戻されたかを自分で確認できる必要がある。
    @job_posting_events = @organization.job_posting_events.includes(:changed_by).recent.limit(50)
  end

  def new
    @job_posting = @organization.job_postings.new(status: "draft")
  end

  def create
    @job_posting = @organization.job_postings.new(job_posting_params.merge(status: "draft"))
    # 誰が作ったかを記録へ残す。
    @job_posting.changed_by = current_user

    if @job_posting.save
      redirect_to organization_job_postings_path(locale: I18n.locale, organization_id: @organization)
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  # 公開されたときと同じ見え方で確認する。どの状態でも見られる。
  def preview
  end

  def update
    if @job_posting.update(job_posting_params)
      redirect_to organization_job_postings_path(locale: I18n.locale, organization_id: @organization)
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def require_editable
      raise ActiveRecord::RecordNotFound unless @job_posting.editable?
    end

    def set_job_posting
      @job_posting = @organization.job_postings.find(params[:id])
    end

    # 状態は画面から受け取らない。公開状態を変える経路は別に用意する。
    def job_posting_params
      params.expect(job_posting: %i[title description location occupation employment_type salary requirements])
    end
end
