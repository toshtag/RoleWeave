ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # レート制限は Rails.cache で数える（ADR 0044）。
    # テストの間で数が持ち越されると、後のテストが上限に達する。
    setup { Rails.cache.clear }

    # 問い合わせの数を数える。
    #
    # N+1 は「動くが遅い」欠陥であり、画面のテストでは気付けない。
    # 件数を増やしても数が増えないことを、この補助で確かめる。
    # 詳細は docs/decisions/0049-query-observability.md を参照する。
    def count_queries
      count = 0

      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
        payload = ActiveSupport::Notifications::Event.new(*args).payload

        next if SlowQueryLogger::IGNORED_NAMES.include?(payload[:name])

        count += 1
      end

      yield

      count
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end
  end
end
