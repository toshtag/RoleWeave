# 運営者専用の経路の土台。
#
# 通常の組織の画面とは分けて置く。混ぜると、組織の所属に基づく制限と
# 運営者の権限が同じ経路の中で絡み合い、どちらで通ったのかが読めなくなる。
# 方針は docs/decisions/0015-operator-role.md を正本とする。
class Operator::BaseController < ApplicationController
  before_action :require_authentication
  before_action :require_confirmed_email
  before_action :require_operator

  private
    # 運営者でない場合は、経路そのものが存在しないものとして扱う。
    # 403 と分けると、運営者の経路が存在することだけが分かる。
    def require_operator
      raise ActiveRecord::RecordNotFound unless current_user&.operator?
    end
end
