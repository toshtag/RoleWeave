require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  config.assume_ssl = true

  # 前段の逆プロキシのうち、どれを信じるか。
  #
  # assume_ssl は「逆プロキシが居る」という前提だが、
  # それだけでは `X-Forwarded-For` を誰が書いたかを区別できない。
  # 区別しないと、header を変えるだけでレート制限（ADR 0044）を数え直させられ、
  # 監査ログ（ADR 0047）へ任意の IP を残せる。
  #
  # 書かない場合は Rails の既定のままとする。
  # 既定で拒否にすると、設定のない起動が理由の分からない失敗になる。
  # 詳細は docs/decisions/0062-reverse-proxy-assumptions.md を参照する。
  trusted_proxies = ReverseProxy.trusted_proxies
  config.action_dispatch.trusted_proxies = trusted_proxies if trusted_proxies.any?

  # 受け入れるホスト名。書かない場合はいままでどおり全てを受け付ける。
  config.hosts += ReverseProxy.allowed_hosts

  # 稼働確認は名前ではなく IP で叩かれる。名前の検証から除く。
  config.host_authorization = { exclude: ->(request) { request.path == "/up" } }

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Skip http-to-https redirect for the default health check endpoint.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  config.cache_store = :solid_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue } }

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Set host to be used by links generated in mailer templates.
  config.action_mailer.default_url_options = { host: "example.com" }

  # Specify outgoing SMTP server. Remember to add smtp/* credentials via bin/rails credentials:edit.
  # config.action_mailer.smtp_settings = {
  #   user_name: Rails.application.credentials.dig(:smtp, :user_name),
  #   password: Rails.application.credentials.dig(:smtp, :password),
  #   address: "smtp.example.com",
  #   port: 587,
  #   authentication: :plain
  # }

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Host ヘッダーの検証は、生成時のコメントではなく上の設定が持つ。
  # 同じ設定を 2 か所に書くと、どちらが効いているのかが読めなくなる。
end
