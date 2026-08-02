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

    # 実行された SQL の文。
    #
    # 数だけでは「どの表を何回引いたか」「どの列を読んだか」
    # 「どういう形で書いたか」が分からない。
    # 値（bind）は Rails が文へ埋めないため、ここにも現れない（ADR 0049）。
    def captured_sql
      statements = []

      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
        payload = ActiveSupport::Notifications::Event.new(*args).payload

        next if SlowQueryLogger::IGNORED_NAMES.include?(payload[:name])

        statements << payload[:sql]
      end

      yield

      statements
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end

    # あるモデルが読み込んだ行の数。
    #
    # 問い合わせの数だけでは、1 回で全件を読む形を検出できない。
    # 「使わない行を読んでいないか」は、行の数でしか見えない。
    def count_loaded(model)
      count = 0

      subscriber = ActiveSupport::Notifications.subscribe("instantiation.active_record") do |*args|
        payload = ActiveSupport::Notifications::Event.new(*args).payload

        count += payload[:record_count] if payload[:class_name] == model.name
      end

      yield

      count
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end
  end
end
