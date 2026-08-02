# スカウトのテンプレート。組織の中で共有する。
class Organizations::ScoutTemplatesController < ApplicationController
  include OrganizationScope

  before_action :require_authentication
  before_action :require_confirmed_email
  before_action :set_organization

  def index
    @scout_templates = @organization.scout_templates.recent
    @scout_template = @organization.scout_templates.build
  end

  def create
    scout_template = @organization.scout_templates.build(scout_template_params)

    flash[:alert] = t(".invalid") unless scout_template.save

    redirect_to organization_scout_templates_path(locale: I18n.locale, organization_id: @organization)
  end

  def destroy
    @organization.scout_templates.find(params[:id]).destroy!

    redirect_to organization_scout_templates_path(locale: I18n.locale, organization_id: @organization)
  end

  private
    def scout_template_params
      params.expect(scout_template: %i[name body])
    end
end
