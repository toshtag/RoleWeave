# 組織の所属と役割の変更の記録。
#
# 「いつからその人が管理者だったか」は後から復元できない。
# 対象の組織とアカウントが削除されても記録は残す。
# 方針は docs/decisions/0014-membership-change-history.md を正本とする。
class MembershipEvent < ApplicationRecord
  # 取り得る出来事。値をここで閉じる。
  # 自由な文字列を許すと、集計のたびに表記のゆれを吸収することになる。
  KINDS = %w[joined role_changed].freeze

  belongs_to :organization, optional: true
  belongs_to :user, optional: true
  belongs_to :changed_by, class_name: "User", optional: true

  # 記録した対象は後から変えない。付け替えられると、履歴が別の組織の話になる。
  attr_readonly :organization_id, :user_id, :kind, :from_role, :to_role

  validates :kind, inclusion: { in: KINDS }
  validates :to_role, inclusion: { in: Membership::ROLES }
  validates :from_role, inclusion: { in: Membership::ROLES }, allow_nil: true
end
