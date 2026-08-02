require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# 例外応答は middleware stack の組み立て時に必要になり、autoload では間に合わない。
# また middleware が保持する定数を reload の対象にしない。
require_relative "../lib/localized_public_exceptions"

# 逆プロキシの前提は環境ごとの設定ファイルが読む。autoload では間に合わない。
require_relative "../lib/reverse_proxy"

# 構造化ログは初期化の早い段階で購読する。autoload では購読の登録が遅れる。
require_relative "../lib/structured_log"
require_relative "../lib/structured_log_subscriber"
require_relative "../lib/slow_query_logger"

module RoleWeave
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    # localized_public_exceptions.rb は上で明示的に読み込む。autoload の対象から外し、
    # 読み込み方が 2 通りある状態を残さない。
    config.autoload_lib(ignore: %w[assets tasks localized_public_exceptions.rb
                              reverse_proxy.rb
                              structured_log.rb structured_log_subscriber.rb
                              slow_query_logger.rb])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # 対応言語を日本語と英語だけへ限定し、日本語を既定とする。
    #
    # enforce_available_locales は Rails の既定値と同じだが明示する。
    # 対応言語の制約を、既定値の記憶ではなくプロジェクトの設定として読める状態へ固定する。
    config.i18n.available_locales = %i[ja en]
    config.i18n.default_locale = :ja
    config.i18n.enforce_available_locales = true

    # 利用者向け表示は日英を同時に実装する。欠落した翻訳を別の言語で補わない。
    #
    # フォールバックを有効にすると、英語の未翻訳が日本語のまま表示され、
    # 翻訳漏れが「動いている」状態に紛れて検出できなくなる。
    config.i18n.fallbacks = false

    # エラー画面も URL のロケールに従わせる。
    #
    # 500 は、アプリケーション側の描画に障害がある状況でも表示できる必要がある。
    # Controller・View・アセットパイプラインを経由せず、public/ の静的 HTML を返す。
    # 詳細は docs/decisions/0003-localized-static-error-pages.md を参照する。
    #
    # 環境ごとに切り替えず、すべての環境で同じ exceptions app を使う。
    # 実際に表示するかどうかは consider_all_requests_local と show_exceptions が決める。
    config.exceptions_app = LocalizedPublicExceptions.new(
      public_path: Rails.public_path,
      available_locales: config.i18n.available_locales,
      default_locale: config.i18n.default_locale
    )
    # 要求とジョブの完了を、1 行の JSON として出す。
    # 詳細は docs/decisions/0048-structured-logging.md を参照する。
    config.after_initialize do
      StructuredLogSubscriber.subscribe(logger: Rails.logger)
      SlowQueryLogger.subscribe(logger: Rails.logger)
    end
  end
end
