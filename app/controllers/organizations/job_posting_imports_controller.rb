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

    # ファイルとして送られたことを確かめる。文字列をそのまま読もうとすると、
    # 入力の誤りが 500 になる。利用者にも運用にも、何が起きたのかが読めない。
    return back_with(t(".missing_file")) unless file.respond_to?(:read)

    run = JobPostingCsv.new(@organization).import(file.read, performed_by: current_user)

    back_with(t(".completed", created: run.created_count, updated: run.updated_count,
                              failed: run.failed_count), kind: :notice)
  rescue JobPostingCsv::TooLarge
    # 大きすぎる入力は取り込まない。途中まで取り込むと、
    # 再実行してよいと言えなくなる（ADR 0058）。
    back_with(t(".too_large", megabytes: JobPostingCsv::MAX_BYTE_SIZE / 1024 / 1024,
                              rows: JobPostingCsv::MAX_ROWS))
  end

  private
    def back_with(message, kind: :alert)
      flash[kind] = message

      redirect_to new_organization_job_posting_import_path(locale: I18n.locale,
                                                          organization_id: @organization)
    end
end
