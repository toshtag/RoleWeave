# 求職者が保存した検索条件。
#
# 条件は求人の検索（ADR 0021）が使う項目に限る。
# ここで別の項目を許すと、検索の側と食い違う条件が保存される。
# 方針は docs/decisions/0054-saved-searches.md を正本とする。
class SavedSearch < ApplicationRecord
  MAX_PER_PROFILE = 20
  NAME_MAX_LENGTH = 100

  # 検索が使う項目だけを条件として持つ。
  PERMITTED_CONDITIONS = Public::JobPostingsController::SEARCH_KEYS.map(&:to_s).freeze

  belongs_to :candidate_profile

  attr_readonly :candidate_profile_id

  normalizes :name, with: ->(name) { name.strip }

  validates :name, presence: true, length: { maximum: NAME_MAX_LENGTH }
  validate :conditions_are_permitted
  validate :within_limit, on: :create

  scope :recent, -> { order(created_at: :desc, id: :desc) }
  scope :notifying, -> { where(notify: true) }

  # 条件に一致する公開中の求人。検索の scope をそのまま使う。
  def matching_job_postings
    JobPosting.published
              .matching_keyword(conditions["keyword"])
              .matching_location(conditions["location"])
              .matching_occupation(conditions["occupation"])
              .matching_employment_type(conditions["employment_type"])
              .matching_minimum_salary(conditions["salary_currency"], conditions["minimum_salary"])
  end

  private
    def conditions_are_permitted
      unknown = conditions.keys - PERMITTED_CONDITIONS
      return if unknown.empty?

      errors.add(:conditions, :unknown_keys)
    end

    def within_limit
      return if candidate_profile.nil?
      return if candidate_profile.saved_searches.count < MAX_PER_PROFILE

      errors.add(:base, :too_many)
    end
end
