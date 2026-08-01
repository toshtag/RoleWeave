class MembershipsController < ApplicationController
  include OrganizationScope

  before_action :require_authentication
  before_action :require_confirmed_email
  before_action :set_organization
  before_action :require_organization_owner, only: :update

  def index
    @memberships = @organization.memberships.includes(:user).order(:role, :id)

    # 履歴は管理者だけが見られる。誰がいつ役割を変えたかは、
    # 組織の運営に属する情報である。
    @membership_events = membership_events if current_membership&.owner?
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
    def membership_events
      @organization.membership_events.includes(:user, :changed_by).order(created_at: :desc, id: :desc).limit(50)
    end

    def membership_params
      params.expect(membership: [ :role ])
    end
end
