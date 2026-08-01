# 組織への招待。
#
# 宛先はメールアドレスとする。招待した時点で相手のアカウントが存在しないことがある。
# アカウントへ結び付けると、その状態を表せない。
# 方針は docs/decisions/0012-organization-invitations.md を正本とする。
class Invitation < ApplicationRecord
  # 受諾リンクの有効期限。
  # 短すぎると気付く前に切れ、長すぎると転送されたメールがいつまでも使える。
  EXPIRES_IN = 7.days

  belongs_to :organization

  # 所属先の組織は、作成した後で変えられないようにする。
  # 変えられると、自分の組織のレコードを他組織へ付け替えられる。
  # 詳細は docs/decisions/0013-role-based-authorization.md を参照する。
  attr_readonly :organization_id

  belongs_to :invited_by, class_name: "User", optional: true

  # 宛先は User と同じ規則で正規化する。規則がずれると、
  # 同じ相手への招待が表記ごとに分かれる。
  normalizes :email_address, with: ->(email_address) { email_address.strip.downcase }

  validates :email_address,
            presence: true,
            format: { with: User::EMAIL_ADDRESS_FORMAT },
            uniqueness: { scope: :organization_id, conditions: -> { pending } }
  validates :role, inclusion: { in: Membership::ROLES }

  scope :pending, -> { where(accepted_at: nil) }

  # 受諾リンクの token。
  #
  # 宛先と受諾時刻を含める。宛先を変えた場合と、受諾済みの場合に
  # 発行済みのリンクを使えなくする。使い切りの印を別に持たなくてよい。
  generates_token_for :acceptance, expires_in: EXPIRES_IN do
    [ email_address, accepted_at&.to_i ]
  end

  def accepted?
    accepted_at.present?
  end

  # 招待を受け入れ、所属を作る。
  #
  # すでに所属があるときは所属を増やさない。招待を受諾済みにするだけとする。
  # 「受諾できなかった」と伝えると、すでに入れている利用者を混乱させる。
  def accept!(user)
    transaction do
      unless organization.users.exists?(user.id)
        # 受諾した本人を変更の主体として記録する。
        organization.memberships.create!(user: user, role: role, changed_by: user)
      end
      update!(accepted_at: Time.current)
    end
  end
end
