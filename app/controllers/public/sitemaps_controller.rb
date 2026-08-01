# 検索エンジンへ、たどってほしい URL の一覧を渡す。
#
# 静的ファイルにすると、自己ホストの利用者ごとにホスト名の書き換えが要る。
# 方針は docs/decisions/0024-structured-data-and-crawling.md を正本とする。
class Public::SitemapsController < ApplicationController
  def show
    @job_postings = JobPosting.published.recent

    render formats: :xml, content_type: "application/xml"
  end
end
