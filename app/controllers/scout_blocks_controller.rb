# 求職者が組織ごとに配信を止める経路。
#
# 「探されてよい」と「この会社からは受け取りたくない」は別である。
# 方針は docs/decisions/0056-scouting.md を正本とする。
class ScoutBlocksController < ApplicationController
  include CandidateProfileScope

  def create
    # 送られてきた組織だけを止められる。任意の組織を指定させない。
    scout = @candidate_profile.scouts.find_by!(organization_id: params[:organization_id])

    @candidate_profile.scout_blocks.find_or_create_by!(organization: scout.organization)

    redirect_to profile_scouts_path(locale: I18n.locale)
  end

  def destroy
    @candidate_profile.scout_blocks.find(params[:id]).destroy!

    redirect_to profile_scouts_path(locale: I18n.locale)
  end
end
