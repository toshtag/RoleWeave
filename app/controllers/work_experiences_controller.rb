# 求職者が自分の職歴を扱う経路。
#
# 対象は常に本人のプロフィールに属する職歴とする。
# 方針は docs/decisions/0027-work-experience.md を正本とする。
class WorkExperiencesController < ApplicationController
  include CandidateProfileScope

  before_action :set_work_experience, only: %i[edit update destroy]

  def index
    @work_experiences = @candidate_profile.work_experiences.recent
  end

  def new
    @work_experience = @candidate_profile.work_experiences.build
  end

  def create
    @work_experience = @candidate_profile.work_experiences.build(work_experience_params)

    if @work_experience.save
      redirect_to profile_work_experiences_path(locale: I18n.locale)
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @work_experience.update(work_experience_params)
      redirect_to profile_work_experiences_path(locale: I18n.locale)
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @work_experience.destroy!

    redirect_to profile_work_experiences_path(locale: I18n.locale)
  end

  private
    # 本人のプロフィールを起点に引く。
    # `WorkExperience.find` にすると、他人の職歴も引けてしまう。
    def set_work_experience
      @work_experience = @candidate_profile.work_experiences.find(params[:id])
    end

    def work_experience_params
      params.expect(work_experience: %i[organization_name position description started_on ended_on])
    end
end
