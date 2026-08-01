# 応募に必要な項目がそろっているかの確認。
#
# 保存せず、そのつど数える。保存すると、更新のたびに数え直す場所が要る。
# **割合や点数として出さない。**「上げるために埋める」圧力になり、
# 応募に不要な個人情報まで書かせることになる。
# 方針は docs/decisions/0029-desired-condition-and-completeness.md を正本とする。
class ProfileCompleteness
  # 確認する項目。名前は辞書のキーとしても使う。
  ITEMS = %i[introduction work_experience education skill desired_condition].freeze

  def initialize(candidate_profile)
    @candidate_profile = candidate_profile
  end

  def filled?(item)
    case item
    when :introduction then @candidate_profile.introduction.present?
    when :work_experience then @candidate_profile.work_experiences.exists?
    when :education then @candidate_profile.educations.exists?
    when :skill then @candidate_profile.skills.exists?
    when :desired_condition then desired_condition_filled?
    else raise ArgumentError, "未知の項目: #{item}"
    end
  end

  def missing_items
    ITEMS.reject { |item| filled?(item) }
  end

  def complete?
    missing_items.empty?
  end

  private
    def desired_condition_filled?
      desired_condition = @candidate_profile.desired_condition

      desired_condition.present? && !desired_condition.blank_conditions?
    end
end
