# 求職者が検索条件を保存する経路。
#
# 条件は検索が使う項目に限る（SavedSearch::PERMITTED_CONDITIONS）。
# 方針は docs/decisions/0054-saved-searches.md を正本とする。
class SavedSearchesController < ApplicationController
  include CandidateProfileScope

  def index
    @saved_searches = @candidate_profile.saved_searches.recent
  end

  def create
    saved_search = @candidate_profile.saved_searches.build(
      name: params[:name].presence || t(".default_name"),
      conditions: conditions_from_params
    )

    flash[:alert] = t(".invalid") unless saved_search.save

    redirect_to profile_saved_searches_path(locale: I18n.locale)
  end

  def update
    saved_search = @candidate_profile.saved_searches.find(params[:id])

    saved_search.update(notify: params[:notify] == "1")

    redirect_to profile_saved_searches_path(locale: I18n.locale)
  end

  def destroy
    @candidate_profile.saved_searches.find(params[:id]).destroy!

    redirect_to profile_saved_searches_path(locale: I18n.locale)
  end

  private
    # 受け取るのは検索が使う項目だけとする。値のない項目は持たない。
    def conditions_from_params
      params.permit(*Public::JobPostingsController::SEARCH_KEYS)
            .to_h
            .select { |_key, value| value.present? }
    end
end
