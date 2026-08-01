# 求職者が自分の希望条件を扱う経路。
#
# 希望条件はプロフィールへ 1 対 1 で従属する。ID を受け取らない。
# 方針は docs/decisions/0029-desired-condition-and-completeness.md を正本とする。
class DesiredConditionsController < ApplicationController
  include CandidateProfileScope

  before_action :set_desired_condition

  def edit
  end

  def update
    if @desired_condition.update(desired_condition_params)
      redirect_to profile_path(locale: I18n.locale)
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    # まだない場合も同じ画面を出す。作成と編集を分けると、
    # 利用者から見て同じ操作が 2 つの入口を持つことになる。
    def set_desired_condition
      @desired_condition = @candidate_profile.desired_condition ||
                           @candidate_profile.build_desired_condition
    end

    def desired_condition_params
      params.expect(desired_condition: %i[employment_type salary_currency annual_salary_min
                                          location available_from note])
    end
end
