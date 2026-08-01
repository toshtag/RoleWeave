# 応募への評価とコメント。
#
# 社内の判断の材料であり、応募者には見せない。
# 求職者側の画面・エクスポート・応募の写しには現れない。
# 方針は docs/decisions/0039-application-review-and-assignment.md を正本とする。
class ApplicationReview < ApplicationRecord
  MIN_RATING = 1
  MAX_RATING = 5
  COMMENT_MAX_LENGTH = 2_000

  belongs_to :job_application
  # 記録した人。アカウントを削除しても記録は残す。
  belongs_to :reviewer, class_name: "User", optional: true

  # 記録した内容は後から変えない。書き換えられると、
  # 誰がいつどう見たかという記録の意味が失われる。
  attr_readonly :job_application_id, :reviewer_id, :rating, :comment

  validates :rating,
            numericality: { only_integer: true,
                            greater_than_or_equal_to: MIN_RATING,
                            less_than_or_equal_to: MAX_RATING },
            allow_nil: true
  validates :comment, length: { maximum: COMMENT_MAX_LENGTH }, allow_blank: true

  # 両方が空の記録は、何も伝えていない。
  validate :rating_or_comment_is_present

  scope :recent, -> { order(created_at: :desc, id: :desc) }

  private
    def rating_or_comment_is_present
      return if rating.present? || comment.present?

      errors.add(:base, :blank_review)
    end
end
