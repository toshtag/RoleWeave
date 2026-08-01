# 求職者の職歴。
#
# 1 つのプロフィールに複数並ぶ。
# 期間の規則は HasPeriod が持つ。学歴と同じ規則である。
# 方針は docs/decisions/0027-work-experience.md を正本とする。
class WorkExperience < ApplicationRecord
  include HasPeriod

  ORGANIZATION_NAME_MAX_LENGTH = 200
  POSITION_MAX_LENGTH = 200
  DESCRIPTION_MAX_LENGTH = 2_000

  belongs_to :candidate_profile

  # 所属先のプロフィールは、作成した後で変えられないようにする。
  # 変えられると、自分の職歴を他人のプロフィールへ付け替えられる。
  attr_readonly :candidate_profile_id

  normalizes :organization_name, with: ->(name) { name.strip }
  normalizes :position, with: ->(position) { position.strip }

  validates :organization_name, presence: true, length: { maximum: ORGANIZATION_NAME_MAX_LENGTH }
  validates :position, presence: true, length: { maximum: POSITION_MAX_LENGTH }
  validates :description, length: { maximum: DESCRIPTION_MAX_LENGTH }, allow_blank: true
end
