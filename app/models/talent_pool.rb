# 企業が候補者を保存しておく場所。
#
# 組織の中で共有する。個人ごとに分けると、担当者が変わったときに引き継げない。
# 方針は docs/decisions/0055-candidate-search.md を正本とする。
class TalentPool < ApplicationRecord
  NAME_MAX_LENGTH = 100
  MAX_PER_ORGANIZATION = 50

  belongs_to :organization

  attr_readonly :organization_id

  has_many :talent_pool_members, dependent: :destroy
  has_many :candidate_profiles, through: :talent_pool_members

  normalizes :name, with: ->(name) { name.strip }

  validates :name, presence: true, length: { maximum: NAME_MAX_LENGTH }
  validates :name, uniqueness: { scope: :organization_id }

  validate :within_limit, on: :create

  scope :recent, -> { order(created_at: :desc, id: :desc) }

  private
    def within_limit
      return if organization.nil?
      return if organization.talent_pools.count < MAX_PER_ORGANIZATION

      errors.add(:base, :too_many)
    end
end
