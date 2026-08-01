# 求職者の職歴。
#
# 1 つのプロフィールに複数並ぶ。
# 方針は docs/decisions/0027-work-experience.md を正本とする。
class WorkExperience < ApplicationRecord
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
  validates :started_on, presence: true

  validate :period_is_ordered
  validate :started_on_is_not_in_the_future

  # 開始日の新しい順とする。並び順を手で指定させると、
  # 職歴を足すたびに全体の並びを見直すことになる。
  scope :recent, -> { order(started_on: :desc, id: :desc) }

  # 終了日を持たない職歴は在籍中として扱う。
  def current?
    ended_on.nil?
  end

  private
    def period_is_ordered
      return if started_on.blank? || ended_on.blank?
      return if ended_on >= started_on

      errors.add(:ended_on, :before_start)
    end

    # 未来の開始日は、まだ始まっていない職歴になる。
    # 応募の時点で語れる経験ではない。
    def started_on_is_not_in_the_future
      return if started_on.blank?
      return if started_on <= Date.current

      errors.add(:started_on, :in_the_future)
    end
end
