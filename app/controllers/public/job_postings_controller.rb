# 求職者が見る求人の経路。
#
# 組織側の管理画面とは分けて置く。混ぜると、
# 「ログインが要る画面」と「誰でも見られる画面」が同じ Controller の中で分岐する。
# 方針は docs/decisions/0020-public-job-posting-urls.md を正本とする。
class Public::JobPostingsController < ApplicationController
  # 絞り込みとページ送りで受け取る query string の名前。
  # 画面の導線もここから組み立て、名前を 2 か所へ書かない。
  SEARCH_KEYS = %i[keyword location occupation employment_type salary_currency minimum_salary].freeze
  PERMITTED_KEYS = (SEARCH_KEYS + %i[page locale]).freeze

  def index
    @search = search_params

    # 絞り込みの条件はモデルの scope が持つ。
    # Controller は受け取った値を渡すだけとし、条件の組み立てを 2 か所へ置かない。
    scope = JobPosting.published
                      .matching_keyword(@search[:keyword])
                      .matching_location(@search[:location])
                      .matching_occupation(@search[:occupation])
                      .matching_employment_type(@search[:employment_type])
                      .matching_minimum_salary(@search[:salary_currency], @search[:minimum_salary])
                      .includes(:organization)
                      .recent

    @pagination = Pagination.new(scope, page: params[:page])
    @job_postings = @pagination.records
  end

  def show
    # 公開中でない求人は、存在しない求人と同じ 404 とする。
    # 分けると、審査中の求人があることだけが分かる。
    @job_posting = JobPosting.published.find(params[:id])
  end

  private
    def search_params
      params.permit(*SEARCH_KEYS).to_h.symbolize_keys.slice(*SEARCH_KEYS)
    end
end
