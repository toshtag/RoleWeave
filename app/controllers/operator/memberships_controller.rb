class Operator::MembershipsController < Operator::BaseController
  # 管理者が 0 人になった組織を復旧するための経路。
  # 与えられるのは管理者の役割だけとし、降格はここでは扱わない。
  def update
    organization = Organization.find(params[:organization_id])
    membership = organization.memberships.find(params[:id])

    # 主体は運営者とする。誰が復旧したかを履歴へ残す。
    membership.changed_by = current_user
    membership.update!(role: "owner")

    redirect_to operator_organization_path(locale: I18n.locale, id: organization)
  end
end
