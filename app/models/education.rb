# 求職者の学歴。
#
# 職歴と同じ形をしており、期間の規則は HasPeriod が持つ。
# 方針は docs/decisions/0028-education-and-skill.md を正本とする。
class Education < ApplicationRecord
  include HasPeriod

  SCHOOL_NAME_MAX_LENGTH = 200
  FIELD_OF_STUDY_MAX_LENGTH = 200
  DEGREE_MAX_LENGTH = 100

  belongs_to :candidate_profile

  attr_readonly :candidate_profile_id

  normalizes :school_name, with: ->(name) { name.strip }

  validates :school_name, presence: true, length: { maximum: SCHOOL_NAME_MAX_LENGTH }
  validates :field_of_study, length: { maximum: FIELD_OF_STUDY_MAX_LENGTH }, allow_blank: true
  validates :degree, length: { maximum: DEGREE_MAX_LENGTH }, allow_blank: true
end
