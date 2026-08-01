# 求職者が自分のプロフィールの公開範囲を決める経路。
#
# 公開範囲はプロフィールの一部だが、編集の画面とは分けて置く。
# ほかの項目と同じ画面にすると、書き換えのついでに範囲が変わりうる。
# 方針は docs/decisions/0030-profile-visibility.md を正本とする。
class ProfileVisibilitiesController < ApplicationController
  include CandidateProfileScope

  def edit
  end

  def update
    if @candidate_profile.update(visibility_params)
      redirect_to profile_path(locale: I18n.locale)
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def visibility_params
      params.expect(candidate_profile: %i[visibility desired_salary_visible])
    end
end
