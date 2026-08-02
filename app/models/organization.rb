# 求人を出す側の企業・団体。
#
# アカウントとの関係は memberships が持つ。アカウントへ直接 organization_id を
# 持たせると、1 人が複数の組織に関わる状況を後から追加できない。
# 方針は docs/decisions/0011-organizations-and-memberships.md を正本とする。
class Organization < ApplicationRecord
  NAME_MAX_LENGTH = 200

  # 組織を消したら、その組織への所属も残さない。
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships

  # 組織を消したら、その組織への招待も残さない。
  has_many :invitations, dependent: :destroy

  # 組織を消したら、その組織の求人も残さない。
  has_many :job_postings, dependent: :destroy

  # 求人の公開状態の履歴は、組織を削除しても残す。
  has_many :job_posting_events, dependent: nil

  # 履歴は組織を削除しても残す。参照は外部キー側で nullify する。
  has_many :membership_events, dependent: nil

  # 応募と取消の記録。応募そのものが消えても残す。
  has_many :job_application_events, dependent: :destroy

  # タレントプール。組織を消したら残さない。
  has_many :talent_pools, dependent: :destroy

  # 送ったスカウトとテンプレート。組織を消したら残さない。
  has_many :scouts, dependent: :destroy
  has_many :scout_templates, dependent: :destroy
  has_many :scout_blocks, dependent: :destroy

  # 外部への配信先。組織を消したら残さない。
  has_many :webhooks, dependent: :destroy

  # 連携の実行の結果。組織を消したら残さない。
  has_many :integration_runs, dependent: :destroy

  # 前後の空白は取り除く。表示名の違いが空白だけ、という状態を作らない。
  normalizes :name, with: ->(name) { name.strip }

  validates :name, presence: true, length: { maximum: NAME_MAX_LENGTH }

  # 組織と、最初の所属を同じトランザクションで作る。
  #
  # 片方だけが残ると、誰も入れない組織ができる。
  # この保証は画面側ではなくモデル側へ置く。作る経路が増えても、
  # 呼び出し側でトランザクションを張り直す必要をなくすためである。
  def self.create_with_owner!(name:, user:, role: "owner")
    transaction do
      organization = create!(name: name)
      organization.memberships.create!(user: user, role: role, changed_by: user)
      organization
    end
  end
end
