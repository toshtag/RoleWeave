# 求職者が自分のプロフィールを扱う経路。
#
# 対象は常に本人のプロフィールとする。ID を受け取らないため、
# 他人のプロフィールを指す方法がない。
# 方針は docs/decisions/0026-candidate-profile.md を正本とする。
class CandidateProfilesController < ApplicationController
  before_action :require_authentication
  before_action :require_confirmed_email

  def show
    @candidate_profile = current_user.candidate_profile

    # まだ作っていない場合は、作成の画面を出す。
    # 空の詳細を見せても、次に何をすればよいかが伝わらない。
    return redirect_to new_profile_path(locale: I18n.locale) if @candidate_profile.nil?

    # 応募に必要な項目がそろっているかの確認。画面の中で数えると、
    # 数え方が画面側へ散らばる。
    @completeness = ProfileCompleteness.new(@candidate_profile)
  end

  def new
    return redirect_to profile_path(locale: I18n.locale) if current_user.candidate_profile

    @candidate_profile = current_user.build_candidate_profile
  end

  def create
    @candidate_profile = current_user.build_candidate_profile(candidate_profile_params)

    if @candidate_profile.save
      redirect_to profile_path(locale: I18n.locale)
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    @candidate_profile = current_user.candidate_profile

    redirect_to new_profile_path(locale: I18n.locale) if @candidate_profile.nil?
  end

  def update
    @candidate_profile = current_user.candidate_profile

    return redirect_to new_profile_path(locale: I18n.locale) if @candidate_profile.nil?

    if @candidate_profile.update(candidate_profile_params)
      redirect_to profile_path(locale: I18n.locale)
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def candidate_profile_params
      params.expect(candidate_profile: %i[display_name introduction location desired_occupation])
    end
end
