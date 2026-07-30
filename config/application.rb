require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module RoleWeave
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

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
  end
end
