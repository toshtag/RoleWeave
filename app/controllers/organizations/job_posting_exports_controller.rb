# 求人の CSV の書き出し。
#
# 扱えるのは組織の管理者だけとする。
# 応募者の情報は出さない。個人情報を CSV で持ち出す経路は作らない。
class Organizations::JobPostingExportsController < ApplicationController
  include OrganizationScope

  before_action :require_authentication
  before_action :require_confirmed_email
  before_action :set_organization
  before_action :require_organization_owner

  def show
    csv = JobPostingCsv.new(@organization).export

    @organization.integration_runs.create!(
      performed_by: current_user, kind: "job_posting_export", status: "completed",
      created_count: 0, updated_count: @organization.job_postings.count, failed_count: 0
    )

    send_data csv,
              filename: "roleweave-job-postings-#{Time.current.strftime("%Y%m%d")}.csv",
              type: "text/csv",
              disposition: "attachment"
  end
end
