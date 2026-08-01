# 求職者が応募に使う基本情報。
#
# アカウント（User）とは分けて持つ。認証に使う情報とは寿命も公開範囲も違い、
# 削除・匿名化でアカウントを残してプロフィールだけを消す場合がある。
# 方針は docs/decisions/0026-candidate-profile.md を正本とする。
class CandidateProfile < ApplicationRecord
  DISPLAY_NAME_MAX_LENGTH = 100
  INTRODUCTION_MAX_LENGTH = 2_000

  # 公開範囲。既定は closed とし、設定しなければ誰にも見えない。
  # 詳細は docs/decisions/0030-profile-visibility.md を参照する。
  VISIBILITIES = %w[closed applied_organizations all_organizations].freeze

  belongs_to :user

  # プロフィールを消したら、その職歴も残さない。
  has_many :work_experiences, dependent: :destroy
  has_many :educations, dependent: :destroy
  has_many :skills, dependent: :destroy
  has_one :desired_condition, dependent: :destroy

  # 所属先のアカウントは、作成した後で変えられないようにする。
  # 変えられると、他人のプロフィールを自分のものにできる。
  attr_readonly :user_id

  normalizes :display_name, with: ->(display_name) { display_name.strip }

  validates :display_name, presence: true, length: { maximum: DISPLAY_NAME_MAX_LENGTH }
  validates :introduction, length: { maximum: INTRODUCTION_MAX_LENGTH }, allow_blank: true
  # 1 アカウントに 1 つだけとする。検証だけでは同時の作成を防げないため、
  # データベース側にも一意インデックスを置く。
  validates :user_id, uniqueness: true

  validates :visibility, inclusion: { in: VISIBILITIES }

  # 企業から見えるプロフィールは、ここだけで決める。
  # 経路ごとに条件を書くと、書き忘れた経路がそのまま個人情報への入口になる。
  #
  # applied_organizations は、応募（P7）ができるまで誰にも見えない。
  # 見えないことは意図であり、実装漏れではない。
  scope :visible_to_organizations, -> { where(visibility: "all_organizations") }
end
