# 検索エンジンへ、たどってほしい URL の一覧を渡す。
#
# 静的ファイルにすると、自己ホストの利用者ごとにホスト名の書き換えが要る。
# 方針は docs/decisions/0024-structured-data-and-crawling.md を正本とする。
class Public::SitemapsController < ApplicationController
  def show
@job_postings = JobPosting.published.recent

# ログイン状態に依存しないため、共有キャッシュへ載せてよい。
expires_in 1.hour, public: true
fresh_when(etag: @job_postings.to_a, last_modified: @job_postings.maximum(:updated_at), public: true)

    render formats: :xml, content_type: "application/xml"
  end
end
