# スカウトの下書き。組織の中で共有する。
#
# 方針は docs/decisions/0056-scouting.md を正本とする。
class ScoutTemplate < ApplicationRecord
  NAME_MAX_LENGTH = 100
  MAX_PER_ORGANIZATION = 20

  belongs_to :organization

  attr_readonly :organization_id

  normalizes :name, with: ->(name) { name.strip }

  validates :name, presence: true, length: { maximum: NAME_MAX_LENGTH }
  validates :name, uniqueness: { scope: :organization_id }
  validates :body, presence: true, length: { maximum: Scout::BODY_MAX_LENGTH }

  validate :within_limit, on: :create

  scope :recent, -> { order(created_at: :desc, id: :desc) }

  private
    def within_limit
      return if organization.nil?
      return if organization.scout_templates.count < MAX_PER_ORGANIZATION

      errors.add(:base, :too_many)
    end
end
