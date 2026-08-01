# リクエストの間だけ有効な、現在のセッションの置き場。
#
# ActiveSupport::CurrentAttributes はリクエストの終わりに自動で消える。
# Controller のインスタンス変数と違い、Model や View から同じ値を参照できる。
class Current < ActiveSupport::CurrentAttributes
  attribute :session

  delegate :user, to: :session, allow_nil: true
end
