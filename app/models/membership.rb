# アカウントが組織に所属していることと、その組織での役割。
class Membership < ApplicationRecord
  # 取り得る役割。値をここで閉じる。
  #
  # owner は組織を運営する側、member は組織の一員として作業する側とする。
  # 役割の細分化は、制限したい操作が決まってから足す。
  # 使い道のない役割を先に並べても、どこで効くのかを誰も判断できない。
  ROLES = %w[owner member].freeze

  belongs_to :organization

  # 所属先の組織は、作成した後で変えられないようにする。
  # 変えられると、自分の組織のレコードを他組織へ付け替えられる。
  # 詳細は docs/decisions/0013-role-based-authorization.md を参照する。
  attr_readonly :organization_id

  belongs_to :user

  validates :role, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :organization_id }

  # 自分自身の役割は変更できない。
  # 誤って自分を降格させると、元へ戻せなくなる。
  validate :role_change_is_not_self_demotion
  # 組織の最後の管理者は降格させない。
  # 管理者が 0 人になると、以後その組織で誰も招待も変更もできなくなる。
  validate :last_owner_remains

  # 所属と役割の変更を記録する。
  #
  # Controller ではなくモデルへ置く。所属を作る・変える経路が増えても、
  # 記録の書き忘れが起こらない。招待の受諾も所属を作る経路である。
  after_create :record_joined
  after_update :record_role_change, if: :saved_change_to_role?

  # 役割を変更する主体。検証のためだけに使い、保存はしない。
  attr_accessor :changed_by

  def owner?
    role == "owner"
  end

  private
    def role_change_is_not_self_demotion
      return unless role_changed? && persisted?
      return unless changed_by && changed_by == user

      errors.add(:role, :self_change)
    end

    def record_joined
      MembershipEvent.create!(
        organization: organization,
        user: user,
        changed_by: changed_by,
        kind: "joined",
        to_role: role
      )
    end

    def record_role_change
      before, after = saved_change_to_role

      MembershipEvent.create!(
        organization: organization,
        user: user,
        changed_by: changed_by,
        kind: "role_changed",
        from_role: before,
        to_role: after
      )
    end

    def last_owner_remains
      return unless role_changed? && persisted?
      return unless role_was == "owner"
      return if organization.memberships.where(role: "owner").where.not(id: id).exists?

      errors.add(:role, :last_owner)
    end
end
