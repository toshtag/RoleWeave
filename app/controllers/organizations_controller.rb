class OrganizationsController < ApplicationController
  before_action :require_authentication
  before_action :require_confirmed_email

  def index
    # 自分が所属する組織だけを出す。すべての組織を出すと、
    # 一覧そのものが「どんな組織が登録されているか」を調べる手段になる。
    @organizations = current_user.organizations.order(:name)
  end

  def new
    @organization = Organization.new
  end

  def create
    # 先に検証して、入力の誤りは画面へ返す。
    # 組織と所属をまとめて作る責務はモデルが持つ（Organization.create_with_owner!）。
    @organization = Organization.new(organization_params)

    if @organization.valid?
      Organization.create_with_owner!(name: @organization.name, user: current_user)

      redirect_to organizations_path(locale: I18n.locale)
    else
      render :new, status: :unprocessable_content
    end
  end

  private
    def organization_params
      params.expect(organization: [ :name ])
    end
end
