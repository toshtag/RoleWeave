class Operator::OrganizationsController < Operator::BaseController
  def index
    @organizations = Organization.order(:name).includes(:memberships)
  end

  def show
    @organization = Organization.find(params[:id])
    @memberships = @organization.memberships.includes(:user).order(:role, :id)
  end
end
