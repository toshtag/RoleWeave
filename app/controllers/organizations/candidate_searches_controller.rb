# 企業が候補者を探す経路。
#
# 対象は**受信を許可した候補者だけ**とする。判定は `CandidateProfile.searchable` が持つ。
# 一覧に並ぶことは、応募先に見せることとは別の同意である（ADR 0030、ADR 0055）。
class Organizations::CandidateSearchesController < ApplicationController
  include OrganizationScope
  include AccessLogging

  # 絞り込みで受け取る項目。ここに書いていない項目は使わない。
  SEARCH_KEYS = %i[skill location desired_occupation].freeze

  before_action :require_authentication
  before_action :require_confirmed_email
  before_action :set_organization

  def index
    @search = params.permit(*SEARCH_KEYS).to_h.symbolize_keys
    scope = CandidateProfile.searchable.includes(:skills)

    scope = scope.where("location ILIKE ?", "%#{sanitize(@search[:location])}%") if @search[:location].present?
    if @search[:desired_occupation].present?
      scope = scope.where("desired_occupation ILIKE ?", "%#{sanitize(@search[:desired_occupation])}%")
    end
    scope = scope.where(id: profiles_with_skill(@search[:skill])) if @search[:skill].present?

    @pagination = Pagination.new(scope.order(:id), page: params[:page])
    @candidate_profiles = @pagination.records

    # プールへ入れる導線を出すために読む。
    @talent_pools = @organization.talent_pools.recent

    # 誰が候補者を探したかを残す。読んだ操作の記録と同じ扱いにする（ADR 0047）。
    record_access("candidate_search_performed",
                  subject: @organization,
                  subject_label: @search.map { |key, value| "#{key}: #{value}" }.join(" / ").presence || "条件なし",
                  organization: @organization)
  end

  private
    def profiles_with_skill(name)
      Skill.where("name ILIKE ?", "%#{sanitize(name)}%").select(:candidate_profile_id)
    end

    def sanitize(value)
      ActiveRecord::Base.sanitize_sql_like(value.to_s)
    end
end
