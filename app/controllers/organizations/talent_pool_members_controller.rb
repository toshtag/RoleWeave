# タレントプールへの候補者の出し入れ。
#
# 入れられるのは、探せる候補者（受信を許可した候補者）だけとする。
class Organizations::TalentPoolMembersController < ApplicationController
  include OrganizationScope

  before_action :require_authentication
  before_action :require_confirmed_email
  before_action :set_organization
  before_action :set_talent_pool

  def create
    # 探せない候補者は、存在しない候補者と同じ 404 とする。
    candidate_profile = CandidateProfile.searchable.find(params[:candidate_profile_id])
    member = @talent_pool.talent_pool_members.build(candidate_profile: candidate_profile,
                                                    added_by: current_user)

    flash[:alert] = t(".invalid") unless member.save

    redirect_to organization_talent_pool_path(locale: I18n.locale, organization_id: @organization,
                                              id: @talent_pool)
  end

  def destroy
    @talent_pool.talent_pool_members.find(params[:id]).destroy!

    redirect_to organization_talent_pool_path(locale: I18n.locale, organization_id: @organization,
                                              id: @talent_pool)
  end

  private
    def set_talent_pool
      @talent_pool = @organization.talent_pools.find(params[:talent_pool_id])
    end
end
