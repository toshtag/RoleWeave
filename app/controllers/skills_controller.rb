# 求職者が自分のスキルを扱う経路。
#
# 対象は常に本人のプロフィールに属するスキルとする。
# 方針は docs/decisions/0028-education-and-skill.md を正本とする。
class SkillsController < ApplicationController
  include CandidateProfileScope

  before_action :set_skill, only: %i[edit update destroy]

  def index
    @skills = @candidate_profile.skills.alphabetical
  end

  def new
    @skill = @candidate_profile.skills.build
  end

  def create
    @skill = @candidate_profile.skills.build(skill_params)

    if @skill.save
      redirect_to profile_skills_path(locale: I18n.locale)
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @skill.update(skill_params)
      redirect_to profile_skills_path(locale: I18n.locale)
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @skill.destroy!

    redirect_to profile_skills_path(locale: I18n.locale)
  end

  private
    def set_skill
      @skill = @candidate_profile.skills.find(params[:id])
    end

    def skill_params
      params.expect(skill: %i[name years_of_experience])
    end
end
