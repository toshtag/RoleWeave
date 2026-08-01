# 組織を対象とする画面の、共通の入口条件。
#
# 対象の組織は、常に「閲覧者が所属する組織」から探す。
# Organization.find で探して後から権限を確かめる形にすると、
# 権限の確認を書き忘れた経路が、そのまま他組織への入口になる。
#
# 方針は docs/decisions/0013-role-based-authorization.md を正本とする。
module OrganizationScope
  extend ActiveSupport::Concern

  included do
    helper_method :current_membership
  end

  private
    # 所属している組織だけを対象にする。
    # 所属していない組織を指定した場合、存在しない組織と同じ応答になる。
    def set_organization
      @organization = current_user.organizations.find(params[:organization_id] || params[:id])
    end

    def current_membership
      @current_membership ||= @organization.memberships.find_by(user: current_user)
    end

    # View からも同じ判定を使う。画面と処理で判断が食い違わないようにする。

    # 管理者だけができる操作へ付ける。
    #
    # 権限がない場合も、存在しない組織と同じ 404 を返す。
    # 403 と分けると、「その組織が存在すること」だけが分かる状態になる。
    def require_organization_owner
      raise ActiveRecord::RecordNotFound unless current_membership&.owner?
    end
end
