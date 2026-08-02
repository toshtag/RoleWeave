# 求人の CSV の取り込み。
#
# 扱えるのは組織の管理者だけとする。
# 方針は docs/decisions/0058-csv-integration.md を正本とする。
class Organizations::JobPostingImportsController < ApplicationController
  include OrganizationScope

  before_action :require_authentication
  before_action :require_confirmed_email
  before_action :set_organization
  before_action :require_organization_owner

  def new
    @integration_runs = @organization.integration_runs.recent.limit(20)
  end

  def create
    file = params[:file]

    if file.blank?
      flash[:alert] = t(".missing_file")

      return redirect_to new_organization_job_posting_import_path(locale: I18n.locale,
                                                                  organization_id: @organization)
    end

    run = JobPostingCsv.new(@organization).import(file.read, performed_by: current_user)

    flash[:notice] = t(".completed", created: run.created_count, updated: run.updated_count,
                                     failed: run.failed_count)

    redirect_to new_organization_job_posting_import_path(locale: I18n.locale,
                                                         organization_id: @organization)
  end
end
