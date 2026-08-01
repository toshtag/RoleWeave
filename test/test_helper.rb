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

    # Add more helper methods to be used by all tests here...
  end
end
