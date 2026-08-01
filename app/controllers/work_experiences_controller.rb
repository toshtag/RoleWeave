# 求職者が自分の職歴を扱う経路。
#
# 対象は常に本人のプロフィールに属する職歴とする。
# プロフィールを起点に引くため、他人の職歴を指す方法がない。
# 方針は docs/decisions/0027-work-experience.md を正本とする。
class WorkExperiencesController < ApplicationController
  before_action :require_authentication
  before_action :require_confirmed_email
  before_action :set_candidate_profile
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
    def set_candidate_profile
      @candidate_profile = current_user.candidate_profile

      # プロフィールがなければ、職歴の置き場所がない。作成の画面へ送る。
      redirect_to new_profile_path(locale: I18n.locale) if @candidate_profile.nil?
    end

    # 本人のプロフィールを起点に引く。
    # `WorkExperience.find` にすると、他人の職歴も引けてしまう。
    def set_work_experience
      @work_experience = @candidate_profile.work_experiences.find(params[:id])
    end

    def work_experience_params
      params.expect(work_experience: %i[organization_name position description started_on ended_on])
    end
end
