# 開始日と終了日を持つ経歴の共通の規則。
#
# 職歴と学歴は同じ形をしている。同じ検証を 2 つのモデルへ書くと、
# 片方だけ直した状態が生まれる。
# 方針は docs/decisions/0027-work-experience.md と
# docs/decisions/0028-education-and-skill.md を正本とする。
module HasPeriod
  extend ActiveSupport::Concern

  included do
    validates :started_on, presence: true

    validate :period_is_ordered
    validate :started_on_is_not_in_the_future

    # 開始日の新しい順とする。並び順を手で指定させると、
    # 経歴を足すたびに全体の並びを見直すことになる。
    scope :recent, -> { order(started_on: :desc, id: :desc) }
  end

  # 終了日を持たない経歴は継続中として扱う。
  def current?
    ended_on.nil?
  end

  private
    def period_is_ordered
      return if started_on.blank? || ended_on.blank?
      return if ended_on >= started_on

      errors.add(:ended_on, :before_start)
    end

    # 未来の開始日は、まだ始まっていない経歴になる。
    # 応募の時点で語れる経験ではない。
    def started_on_is_not_in_the_future
      return if started_on.blank?
      return if started_on <= Date.current

      errors.add(:started_on, :in_the_future)
    end
end
