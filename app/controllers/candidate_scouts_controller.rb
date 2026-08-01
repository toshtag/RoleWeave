# 求職者が受け取ったスカウトを見る経路。
#
# 対象は常に本人のプロフィールとする。
class CandidateScoutsController < ApplicationController
  include CandidateProfileScope

  def index
    @scouts = @candidate_profile.scouts.includes(:organization, :job_posting).recent
    @blocked_organization_ids = @candidate_profile.scout_blocks.pluck(:organization_id)
  end
end
