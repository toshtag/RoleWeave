# 求職者のスキル。
#
# 期間を持たない。名前と経験年数だけを持つ。
# 方針は docs/decisions/0028-education-and-skill.md を正本とする。
class Skill < ApplicationRecord
  NAME_MAX_LENGTH = 100
  # 経験年数の上限。人が働ける長さを超える値は入力の誤りとして拒否する。
  MAX_YEARS_OF_EXPERIENCE = 80

  belongs_to :candidate_profile

  attr_readonly :candidate_profile_id

  normalizes :name, with: ->(name) { name.strip }

  validates :name, presence: true, length: { maximum: NAME_MAX_LENGTH }
  # 同じスキルが 2 つ並ぶと、読み手はどちらが正しいか判断できない。
  validates :name, uniqueness: { scope: :candidate_profile_id }

  validates :years_of_experience,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 0,
              less_than_or_equal_to: MAX_YEARS_OF_EXPERIENCE
            },
            allow_nil: true

  # 名前の昇順とする。経験年数を主にすると、
  # 未入力のスキルをどこへ置くかを決めることになる。
  scope :alphabetical, -> { order(:name, :id) }
end
