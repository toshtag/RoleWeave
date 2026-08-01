require "test_helper"

# 負荷試験の仕組みそのものを検証する。
#
# 測る道具が壊れていると、測った値が信じられなくなる。
class LoadTestTaskTest < ActiveSupport::TestCase
  test "データがなくても測定が落ちない" do
    results = LoadTestMeasurement.new(iterations: 1).run

    assert_not_empty results
    results.each { |result| assert_equal "200", result[:status], "#{result[:name]} の状態" }
  end

  test "測定が経路ごとの値を返す" do
    result = LoadTestMeasurement.new(iterations: 2).run.first

    assert_equal 2, result[:iterations]
    assert_operator result[:p50], :>=, 0
    assert_operator result[:p95], :>=, result[:p50]
    assert_operator result[:max], :>=, result[:p95]
  end

  test "データを作って消せる" do
    data = LoadTestData.new

    assert_difference -> { JobPosting.count }, 3 do
      data.seed(job_postings: 3)
    end

    assert_difference -> { JobPosting.count }, -3 do
      data.clean
    end
  end

  test "作ったデータは公開中の求人である" do
    LoadTestData.new.seed(job_postings: 2)

    assert_equal 2, JobPosting.published.count
  ensure
    LoadTestData.new.clean
  end

  test "データ量の要約を返す" do
    assert_match(/求人 \d+ 件/, LoadTestData.new.summary)
  end
end
