# 求職者が応募に使う基本情報。
#
# アカウント（User）とは分けて持つ。認証に使う情報とは寿命も公開範囲も違い、
# 削除・匿名化でアカウントを残してプロフィールだけを消す場合がある。
# 方針は docs/decisions/0026-candidate-profile.md を正本とする。
class CandidateProfile < ApplicationRecord
  DISPLAY_NAME_MAX_LENGTH = 100
  INTRODUCTION_MAX_LENGTH = 2_000

  belongs_to :user

  # プロフィールを消したら、その職歴も残さない。
  has_many :work_experiences, dependent: :destroy

  # 所属先のアカウントは、作成した後で変えられないようにする。
  # 変えられると、他人のプロフィールを自分のものにできる。
  attr_readonly :user_id

  normalizes :display_name, with: ->(display_name) { display_name.strip }

  validates :display_name, presence: true, length: { maximum: DISPLAY_NAME_MAX_LENGTH }
  validates :introduction, length: { maximum: INTRODUCTION_MAX_LENGTH }, allow_blank: true
  # 1 アカウントに 1 つだけとする。検証だけでは同時の作成を防げないため、
  # データベース側にも一意インデックスを置く。
  validates :user_id, uniqueness: true
end
