# 求職者が保存した求人。
#
# 方針は docs/decisions/0054-saved-searches.md を正本とする。
class SavedJobPosting < ApplicationRecord
  # 保存できる件数の上限。無制限にすると、一覧の読み出しが際限なく重くなる。
  MAX_PER_PROFILE = 200

  belongs_to :candidate_profile
  belongs_to :job_posting

  attr_readonly :candidate_profile_id, :job_posting_id

  # 同じ求人を 2 回保存しても意味がない。
  validates :job_posting_id, uniqueness: { scope: :candidate_profile_id }

  validate :within_limit, on: :create

  scope :recent, -> { order(created_at: :desc, id: :desc) }

  private
    def within_limit
      return if candidate_profile.nil?
      return if candidate_profile.saved_job_postings.count < MAX_PER_PROFILE

      errors.add(:base, :too_many)
    end
end
