class JobPostingsController < ApplicationController
  include OrganizationScope

  before_action :require_authentication
  before_action :require_confirmed_email
  before_action :set_organization
  before_action :set_job_posting, only: %i[edit update]

  def index
    # 自組織の求人だけを出す。対象は set_organization がすでに絞っている。
    @job_postings = @organization.job_postings.recent
  end

  def new
    @job_posting = @organization.job_postings.new(status: "draft")
  end

  def create
    @job_posting = @organization.job_postings.new(job_posting_params.merge(status: "draft"))

    if @job_posting.save
      redirect_to organization_job_postings_path(locale: I18n.locale, organization_id: @organization)
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @job_posting.update(job_posting_params)
      redirect_to organization_job_postings_path(locale: I18n.locale, organization_id: @organization)
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_job_posting
      @job_posting = @organization.job_postings.find(params[:id])
    end

    # 状態は画面から受け取らない。公開状態を変える経路は別に用意する。
    def job_posting_params
      params.expect(job_posting: %i[title description location occupation employment_type salary requirements])
    end
end
