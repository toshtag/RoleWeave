source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.3"
# Rails 標準機能の日本語ロケールデータ [https://github.com/svenfuchs/rails-i18n]
# Active Model のエラー文言、日付、時刻、数値形式を自前で複製すると、
# Rails の更新へ追随できず、翻訳の網羅性と一貫性も維持できない。
gem "rails-i18n", "~> 8.1.0"
# CSV の読み書き [https://github.com/ruby/csv]
# Ruby 3.4 以降、csv は default gem から bundled gem へ移った。
# Ruby 本体と同じ配布物であり、第三者の依存ではないが、明示しないと読み込めない。
# 引用符・改行・エスケープの規則を自前で実装すると、誤りが静かにデータを壊す。
gem "csv", "~> 3.3"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"

# Stimulus の controller を 1 つも持たないため、stimulus-rails は宣言しない（ADR 0068）。
# `*_controller.js` も `data-controller` も 0 件である。
# 宣言すると、すべての画面で stimulus.min.js と stimulus-loading.js を配ることになる。
# 費用を払うのは画面を開く人の回線と端末であり、開発環境ではない。
# JavaScript の振る舞いが必要になったときは、何に使うかと合わせて足す。

# JSON を返す経路を持たないため、jbuilder は宣言しない。
# `.jbuilder` テンプレートも `format.json` も `render json` も使っていない。
# 画面は HTML を返し、機械向けの出力は sitemap.xml と CSV が担う。

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# パスワードのハッシュ化を自前で実装しない。ソルトの生成、反復回数の埋め込み、
# 比較の時間差対策を自作すると、そのすべてが検証対象になる。
# 方針は docs/decisions/0006-password-storage-and-policy.md を正本とする。
gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache and Active Job
#
# solid_cache は Rails.cache を直接呼ぶ箇所が無くても外せない。
# Rails 8 の rate_limit が既定で config.cache_store を使う（ADR 0044）。
# production の cache_store は :solid_cache_store であり、
# 外すと本番のレート制限がプロセスローカルになる。
#
# Action Cable を読み込まないため、solid_cable は宣言しない（ADR 0065）。
gem "solid_cache"
gem "solid_queue"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# 画像の variant を生成しないため、image_processing とその backend
# （mini_magick、ruby-vips）を宣言しない（ADR 0064）。
# 宣言すると、使わない変換の経路のために、ホストと CI runner を含む
# 全実行環境へ libvips または ImageMagick を要求することになる。
# variant が必要になったときは、実行環境の前提と一緒に足す。

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

# system test を持たないため、capybara と selenium-webdriver は宣言しない。
# test/system/ も test/application_system_test_case.rb も存在しない。
# 画面の検証は integration test が担う。
# 実ブラウザでの検証を始めるときは、その Issue で
# 依存・実行環境（ブラウザと driver）・CI の前提をまとめて足す。
