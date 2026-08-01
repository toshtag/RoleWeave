# 求職者が自分の学歴を扱う経路。
#
# 対象は常に本人のプロフィールに属する学歴とする。
# 方針は docs/decisions/0028-education-and-skill.md を正本とする。
class EducationsController < ApplicationController
  include CandidateProfileScope

  before_action :set_education, only: %i[edit update destroy]

  def index
    @educations = @candidate_profile.educations.recent
  end

  def new
    @education = @candidate_profile.educations.build
  end

  def create
    @education = @candidate_profile.educations.build(education_params)

    if @education.save
      redirect_to profile_educations_path(locale: I18n.locale)
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @education.update(education_params)
      redirect_to profile_educations_path(locale: I18n.locale)
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @education.destroy!

    redirect_to profile_educations_path(locale: I18n.locale)
  end

  private
    def set_education
      @education = @candidate_profile.educations.find(params[:id])
    end

    def education_params
      params.expect(education: %i[school_name field_of_study degree started_on ended_on])
    end
end
