# 求職者の希望条件。
#
# プロフィールへ 1 対 1 で従属する。
# 雇用形態と通貨は求人と同じ語彙を使う。食い違うと突き合わせができない。
# 方針は docs/decisions/0029-desired-condition-and-completeness.md を正本とする。
class DesiredCondition < ApplicationRecord
  # 求人の語彙をそのまま参照する。写して持つと、片方だけ増えた状態が生まれる。
  EMPLOYMENT_TYPES = JobPosting::EMPLOYMENT_TYPES
  SALARY_CURRENCIES = JobPosting::SALARY_CURRENCIES

  LOCATION_MAX_LENGTH = 200
  NOTE_MAX_LENGTH = 1_000

  belongs_to :candidate_profile

  attr_readonly :candidate_profile_id

  normalizes :location, with: ->(location) { location.strip }

  validates :candidate_profile_id, uniqueness: true

  validates :employment_type, inclusion: { in: EMPLOYMENT_TYPES }, allow_blank: true
  validates :salary_currency, inclusion: { in: SALARY_CURRENCIES }, allow_blank: true

  validates :annual_salary_min,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 },
            allow_nil: true

  validates :location, length: { maximum: LOCATION_MAX_LENGTH }, allow_blank: true
  validates :note, length: { maximum: NOTE_MAX_LENGTH }, allow_blank: true

  validate :salary_has_currency

  # 何も書かれていない希望条件は、条件を示していない。
  def blank_conditions?
    employment_type.blank? && salary_currency.blank? && annual_salary_min.nil? &&
      location.blank? && available_from.nil? && note.blank?
  end

  private
    # 通貨のない金額は読めない。金額のない通貨は何も示していない。
    def salary_has_currency
      return if annual_salary_min.nil? == salary_currency.blank?

      errors.add(:salary_currency, :incomplete_salary)
    end
end
