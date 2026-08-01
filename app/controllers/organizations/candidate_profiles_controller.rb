# 企業側から求職者のプロフィールを見る経路。
#
# 見えるかどうかは `CandidateProfile.visible_to_organizations` だけが決める。
# ここに条件を書き足すと、判定が 2 か所へ分かれる。
#
# 一覧は持たない。候補者の検索は P6 の非目標であり、
# 一覧があること自体が、公開範囲を「探されてよい」という意味へ変えてしまう。
# 方針は docs/decisions/0030-profile-visibility.md を正本とする。
class Organizations::CandidateProfilesController < ApplicationController
  include OrganizationScope

  before_action :require_authentication
  before_action :require_confirmed_email
  before_action :set_organization

  def show
    # 見えないプロフィールは、存在しないプロフィールと同じ 404 とする。
    # 分けると、そのプロフィールがあることだけが分かる。
    @candidate_profile = CandidateProfile.visible_to_organizations
                                         .includes(:work_experiences, :educations, :skills, :desired_condition)
                                         .find(params[:id])
  end
end
