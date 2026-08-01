require "test_helper"

# 公開求人の絞り込みの契約を検証する。
#
# 検証対象は、どの入力がどの求人を返すかである。
# 画面と経路は public_job_postings_test が持つ。
class JobPostingSearchTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(name: "Example Inc.")

    @recruiter = create(
      title: "採用担当", description: "採用の実務を担当します。",
      occupation: "人事", location: "東京", employment_type: "full_time"
    )
    @engineer = create(
      title: "Backend Engineer", description: "Rails でサービスを開発します。",
      occupation: "エンジニア", location: "大阪", employment_type: "contract"
    )
  end

  test "題名の部分一致で見つかる" do
    assert_equal [ @recruiter ], JobPosting.matching_keyword("採用").to_a
  end

  test "仕事内容の部分一致で見つかる" do
    assert_equal [ @engineer ], JobPosting.matching_keyword("Rails").to_a
  end

  test "職種と勤務地でも見つかる" do
    assert_equal [ @recruiter ], JobPosting.matching_keyword("人事").to_a
    assert_equal [ @engineer ], JobPosting.matching_keyword("大阪").to_a
  end

  test "大文字小文字を区別しない" do
    assert_equal [ @engineer ], JobPosting.matching_keyword("backend").to_a
  end

  test "複数の語はすべてを含む求人だけを返す" do
    # いずれかを含む条件にすると、語を足すほど結果が増えて絞り込みにならない。
    assert_equal [ @engineer ], JobPosting.matching_keyword("Backend 大阪").to_a
    assert_empty JobPosting.matching_keyword("Backend 東京").to_a
  end

  test "空のキーワードはすべてを返す" do
    assert_equal 2, JobPosting.matching_keyword("").count
    assert_equal 2, JobPosting.matching_keyword(nil).count
    assert_equal 2, JobPosting.matching_keyword("   ").count
  end

  test "部分一致の記号をそのままの文字として扱う" do
    # これを外すと、利用者の入力が部分一致の記号として解釈される。
    assert_empty JobPosting.matching_keyword("%").to_a
    assert_empty JobPosting.matching_keyword("_").to_a

    create(title: "100% リモート", description: "内容")

    assert_equal 1, JobPosting.matching_keyword("100%").count
  end

  test "勤務地と職種で絞り込める" do
    assert_equal [ @recruiter ], JobPosting.matching_location("東京").to_a
    assert_equal [ @engineer ], JobPosting.matching_occupation("エンジニア").to_a
  end

  test "雇用形態は決められた値だけを条件にする" do
    assert_equal [ @recruiter ], JobPosting.matching_employment_type("full_time").to_a
    # 決められていない値は条件として無視する。
    assert_equal 2, JobPosting.matching_employment_type("unknown").count
    assert_equal 2, JobPosting.matching_employment_type(nil).count
  end

  test "条件を組み合わせられる" do
    assert_equal [ @recruiter ],
                 JobPosting.matching_keyword("採用").matching_location("東京").to_a
    assert_empty JobPosting.matching_keyword("採用").matching_location("大阪").to_a
  end

  test "絞り込んでも公開中でない求人は出ない" do
    create(title: "下書きの採用担当", description: "内容", status: "draft")

    assert_equal [ @recruiter ], JobPosting.published.matching_keyword("採用").to_a
  end

  test "通貨と最低年収で絞り込める" do
    @recruiter.update!(salary_currency: "JPY", annual_salary_min: 5_000_000)
    @engineer.update!(salary_currency: "JPY", annual_salary_min: 8_000_000)

    assert_equal [ @engineer ], JobPosting.matching_minimum_salary("JPY", 6_000_000).to_a
    assert_equal 2, JobPosting.matching_minimum_salary("JPY", 5_000_000).count
  end

  test "通貨をまたいだ比較をしない" do
    # 換算は為替の時点を決めないと成り立たない。
    @recruiter.update!(salary_currency: "JPY", annual_salary_min: 5_000_000)
    @engineer.update!(salary_currency: "USD", annual_salary_min: 80_000)

    assert_equal [ @recruiter ], JobPosting.matching_minimum_salary("JPY", 1_000).to_a
    assert_equal [ @engineer ], JobPosting.matching_minimum_salary("USD", 1_000).to_a
  end

  test "金額を持たない求人は金額の条件で出ない" do
    # 「未記載」を「条件を満たす」と扱うと、結果が信用できなくなる。
    @recruiter.update!(salary_currency: "JPY", annual_salary_min: 5_000_000)

    assert_equal [ @recruiter ], JobPosting.matching_minimum_salary("JPY", 1_000).to_a
  end

  test "最低年収が空なら絞り込まない" do
    assert_equal 2, JobPosting.matching_minimum_salary("JPY", "").count
    assert_equal 2, JobPosting.matching_minimum_salary("JPY", nil).count
  end

  test "決められていない通貨では絞り込まない" do
    assert_equal 2, JobPosting.matching_minimum_salary("BTC", 1_000).count
    assert_equal 2, JobPosting.matching_minimum_salary(nil, 1_000).count
  end

  private
    def create(status: "published", **attributes)
      @organization.job_postings.create!({ status: status }.merge(attributes))
    end
end
