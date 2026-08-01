# 求職者が見る求人の経路。
#
# 組織側の管理画面とは分けて置く。混ぜると、
# 「ログインが要る画面」と「誰でも見られる画面」が同じ Controller の中で分岐する。
# 方針は docs/decisions/0020-public-job-posting-urls.md を正本とする。
class Public::JobPostingsController < ApplicationController
  def index
    @job_postings = JobPosting.published.includes(:organization).recent
  end

  def show
    # 公開中でない求人は、存在しない求人と同じ 404 とする。
    # 分けると、審査中の求人があることだけが分かる。
    @job_posting = JobPosting.published.find(params[:id])
  end
end
