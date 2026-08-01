# 一覧をページに分けるための値オブジェクト。
#
# gem を足さずに済ませる。必要なのは「何件目から何件」と
# 「前後のページがあるか」の 2 つだけであり、
# それだけのために依存を 1 つ増やさない。
# 方針は docs/decisions/0023-pagination.md を正本とする。
class Pagination
  DEFAULT_PER_PAGE = 20

  attr_reader :current_page, :per_page, :total_count

  def initialize(scope, page:, per_page: DEFAULT_PER_PAGE)
    @scope = scope
    @per_page = per_page
    # 総件数は先に数える。ページ番号の丸めに要る。
    @total_count = scope.count
    @current_page = normalize_page(page)
  end

  def records
    @records ||= @scope.limit(per_page).offset((current_page - 1) * per_page)
  end

  def total_pages
    # 0 件でも 1 ページとする。「0 ページ目」を表示する画面がない。
    [ (total_count.to_f / per_page).ceil, 1 ].max
  end

  def previous_page
    current_page - 1 if current_page > 1
  end

  def next_page
    current_page + 1 if current_page < total_pages
  end

  private
    # 範囲外のページ番号は 1 ページ目へ丸める。
    #
    # エラーにしない。URL を手で書き換えた場合や、
    # 求人が減ってページが消えた場合に、404 を返す理由がない。
    def normalize_page(page)
      number = page.to_i

      return 1 if number < 1 || number > total_pages

      number
    end
end
