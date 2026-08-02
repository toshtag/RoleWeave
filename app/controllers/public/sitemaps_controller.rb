# 検索エンジンへ、たどってほしい URL の一覧を渡す。
#
# 静的ファイルにすると、自己ホストの利用者ごとにホスト名の書き換えが要る。
# 方針は docs/decisions/0024-structured-data-and-crawling.md を正本とする。
class Public::SitemapsController < ApplicationController
  def show
    # View が使うのは id（URL）と updated_at（lastmod）だけである。
    # 列を絞らないと description（必須の text）まで読む。
    # 求人 5 万件の見積もり（容量モデル）では、読んで捨てる量がそのまま応答時間に出る。
    @job_postings = JobPosting.published.recent.select(:id, :updated_at).to_a

    # ログイン状態に依存しないため、共有キャッシュへ載せてよい。
    expires_in 1.hour, public: true
    # Last-Modified は読み込み済みの求人から作る。
    # relation の maximum を呼ぶと、読み終えた後にもう一度全件を走査する。
    fresh_when(etag: @job_postings, last_modified: @job_postings.map(&:updated_at).max, public: true)

    # 内容が変わっていなければ、fresh_when がここで 304 を返す。
    # **その場合は描画へ進まない。**進むと 2 回目の描画になり、
    # AbstractController::DoubleRenderError で 500 になる。
    # fresh_when は 304 を返したかどうかを返り値では示さないため、performed? で見る。
    return if performed?

    render formats: :xml, content_type: "application/xml"
  end
end
