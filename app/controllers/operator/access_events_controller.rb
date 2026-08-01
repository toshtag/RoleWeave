# 個人情報を読んだ操作の一覧。
#
# 運営者だけが見る。誰が誰の情報を読んだかは、それ自体が個人に関わる情報である。
# 方針は docs/decisions/0047-access-audit-log.md を正本とする。
class Operator::AccessEventsController < Operator::BaseController
  def index
    @access_events = AccessEvent.includes(:actor, :organization).recent.limit(200)
  end
end
