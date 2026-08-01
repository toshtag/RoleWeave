class MembershipsController < ApplicationController
  include OrganizationScope

  before_action :require_authentication
  before_action :require_confirmed_email
  before_action :set_organization
  before_action :require_organization_owner, only: :update

  def index
    @memberships = @organization.memberships.includes(:user).order(:role, :id)
  end

  def update
    membership = @organization.memberships.find(params[:id])
    # 誰が変更しようとしているかを検証へ渡す。自分自身の降格を防ぐために要る。
    membership.changed_by = current_user

    if membership.update(membership_params)
      redirect_to organization_memberships_path(locale: I18n.locale, organization_id: @organization)
    else
      @memberships = @organization.memberships.includes(:user).order(:role, :id)
      @errors = membership.errors

      render :index, status: :unprocessable_content
    end
  end

  private
    def membership_params
      params.expect(membership: [ :role ])
    end
end
