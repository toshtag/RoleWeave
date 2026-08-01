require "test_helper"

# ページ分割の契約を検証する。
#
# 検証対象は、何件目から何件を返すかと、前後のページの有無である。
class PaginationTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(name: "Example Inc.")
    25.times { |index| create_job_posting("求人 #{index}") }
    @scope = @organization.job_postings.order(:id)
  end

  test "1 ページ目は先頭から件数分を返す" do
    pagination = Pagination.new(@scope, page: 1, per_page: 20)

    assert_equal 20, pagination.records.size
    assert_equal 1, pagination.current_page
  end

  test "2 ページ目は続きを返す" do
    pagination = Pagination.new(@scope, page: 2, per_page: 20)

    assert_equal 5, pagination.records.size
    assert_equal @scope.offset(20).first, pagination.records.first
  end

  test "総ページ数を件数から求める" do
    assert_equal 2, Pagination.new(@scope, page: 1, per_page: 20).total_pages
    assert_equal 3, Pagination.new(@scope, page: 1, per_page: 10).total_pages
  end

  test "前後のページの有無を返す" do
    first = Pagination.new(@scope, page: 1, per_page: 20)
    last = Pagination.new(@scope, page: 2, per_page: 20)

    assert_nil first.previous_page
    assert_equal 2, first.next_page
    assert_equal 1, last.previous_page
    assert_nil last.next_page
  end

  test "範囲外のページ番号を 1 ページ目として扱う" do
    # URL を手で書き換えた場合や、求人が減ってページが消えた場合に、
    # 404 を返す理由がない。
    [ 0, -1, 999, "abc", nil, "" ].each do |page|
      assert_equal 1, Pagination.new(@scope, page: page, per_page: 20).current_page,
        "#{page.inspect} が 1 ページ目にならない"
    end
  end

  test "0 件でも 1 ページとして扱う" do
    empty = Pagination.new(@organization.job_postings.where(title: "存在しない"), page: 1, per_page: 20)

    assert_equal 0, empty.total_count
    assert_equal 1, empty.total_pages
    assert_empty empty.records
    assert_nil empty.next_page
  end

  private
    def create_job_posting(title)
      @organization.job_postings.create!(status: "published", title: title, description: "内容")
    end
end
