# アカウントが組織に所属していることと、その組織での役割。
class Membership < ApplicationRecord
  # 取り得る役割。値をここで閉じる。
  #
  # owner は組織を運営する側、member は組織の一員として作業する側とする。
  # 役割の細分化は、制限したい操作が決まってから足す。
  # 使い道のない役割を先に並べても、どこで効くのかを誰も判断できない。
  ROLES = %w[owner member].freeze

  belongs_to :organization
  belongs_to :user

  validates :role, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :organization_id }

  def owner?
    role == "owner"
  end
end
