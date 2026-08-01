# 企業から候補者への働きかけ。
#
# 探されることと、何通も送られることは別である。
# 上限と配信停止で、送りすぎを止める。
# 方針は docs/decisions/0056-scouting.md を正本とする。
class Scout < ApplicationRecord
  BODY_MAX_LENGTH = 2_000
  # 1 つの組織が 1 日に送れる数。
  #
  # 上限がないと、1 つの組織が一覧のすべてへ送れる。
  # 値そのものに強い根拠はない。運用の実績に応じて見直す。
  DAILY_LIMIT_PER_ORGANIZATION = 50

  belongs_to :organization
  belongs_to :candidate_profile
  belongs_to :sent_by, class_name: "User", optional: true
  belongs_to :job_posting, optional: true

  # 送った内容は後から変えない。相手が読んだものと食い違う。
  attr_readonly :organization_id, :candidate_profile_id, :sent_by_id, :job_posting_id, :body

  validates :body, presence: true, length: { maximum: BODY_MAX_LENGTH }
  # 同じ組織から同じ候補者へ 2 通目を送れない。
  validates :candidate_profile_id, uniqueness: { scope: :organization_id }

  validate :candidate_is_searchable, on: :create
  validate :candidate_has_not_blocked, on: :create
  validate :within_daily_limit, on: :create

  scope :recent, -> { order(created_at: :desc, id: :desc) }

  private
    # 受信を許可していない候補者へは送れない（ADR 0055）。
    def candidate_is_searchable
      return if candidate_profile.nil?
      return if CandidateProfile.searchable.exists?(candidate_profile.id)

      errors.add(:candidate_profile, :not_searchable)
    end

    def candidate_has_not_blocked
      return if candidate_profile.nil? || organization.nil?
      return unless ScoutBlock.exists?(candidate_profile: candidate_profile, organization: organization)

      errors.add(:candidate_profile, :blocked)
    end

    def within_daily_limit
      return if organization.nil?
      return if organization.scouts.where(created_at: Time.current.all_day).count < DAILY_LIMIT_PER_ORGANIZATION

      errors.add(:base, :daily_limit_reached)
    end
end
