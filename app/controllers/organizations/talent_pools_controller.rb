# タレントプールを扱う経路。
#
# 対象は所属する組織のプールだけとする。
class Organizations::TalentPoolsController < ApplicationController
  include OrganizationScope

  before_action :require_authentication
  before_action :require_confirmed_email
  before_action :set_organization

  def index
    @talent_pools = @organization.talent_pools.includes(:searchable_members).recent
    @talent_pool = @organization.talent_pools.build
  end

  def show
    @talent_pool = @organization.talent_pools.find(params[:id])
    @members = @talent_pool.searchable_members.includes(:candidate_profile, :added_by).recent
  end

  def create
    talent_pool = @organization.talent_pools.build(name: params[:name])

    flash[:alert] = t(".invalid") unless talent_pool.save

    redirect_to organization_talent_pools_path(locale: I18n.locale, organization_id: @organization)
  end

  def destroy
    @organization.talent_pools.find(params[:id]).destroy!

    redirect_to organization_talent_pools_path(locale: I18n.locale, organization_id: @organization)
  end
end
