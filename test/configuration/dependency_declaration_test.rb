require "test_helper"

# 依存の宣言と、実際に使っているものを一致させる契約を検証する。
#
# ずれは 2 方向で起きる。どちらも「テストが緑」では気付けない。
#
#   宣言しているが使っていない  更新も脆弱性の追跡も、
#                               何のために続けているのか分からないまま続く
#   使っているが宣言していない  たまたま同じ環境で読み込まれている
#                               別の gem に依存する。外した瞬間に落ちる
#
# 後者は実際に起きていた。app/jobs/webhook_delivery_job.rb が Net::HTTP を
# 使いながら require を書いておらず、test group の gem（capybara、
# selenium-webdriver）が巻き添えで読み込んでいた。
# test group は production では読まれないため、production では
# 最初の Webhook 配信で NameError になる状態だった。
class DependencyDeclarationTest < ActiveSupport::TestCase
  # 落とした gem。戻すときは、何に使うかを Gemfile のコメントへ書いてから戻す。
  #
  #   jbuilder            JSON を返す経路がない
  #   capybara            system test がない
  #   selenium-webdriver  同上
  #   solid_cable         Action Cable を読み込まない（ADR 0065）
  #   stimulus-rails      controller を 1 つも持たない（ADR 0068）
  REMOVED_GEMS = %w[jbuilder capybara selenium-webdriver solid_cable stimulus-rails].freeze

  # 読み込まない Rails のフレームワーク（ADR 0065）。
  UNLOADED_FRAMEWORKS = %w[ActionCable ActionText ActionMailbox].freeze

  # 読み込むフレームワーク。
  # 片側だけを検査すると、require の一覧をまとめて削っても気付けない。
  LOADED_FRAMEWORKS = %w[
    ActiveRecord ActiveStorage ActionController
    ActionView ActionMailer ActiveJob
  ].freeze

  # Rails が読み込まない標準ライブラリと、それを使っていると判断する目印。
  #
  # ここが短いのは、実装が使う他の標準ライブラリ（ipaddr、openssl、
  # securerandom、uri、timeout、csv）が、Rails 本体か既存の require によって
  # 起動時点で読み込まれていることを実測したためである。
  # 網羅ではなく、実測して欠けていたものを固定している。
  UNDECLARED_UNLESS_REQUIRED = {
    "net/http" => /\bNet::HTTP/
  }.freeze

  SOURCE_ROOTS = %w[app lib].freeze

  test "使っていない gem を依存へ残さない" do
    REMOVED_GEMS.each do |gem_name|
      assert_raises(LoadError, "#{gem_name} が依存に残っている") do
        require gem_name
      end
    end
  end

  test "使っていない Rails のフレームワークを読み込まない" do
    UNLOADED_FRAMEWORKS.each do |framework|
      assert_nil defined?(framework) && (Object.const_get(framework) rescue nil),
        "#{framework} が読み込まれている。config/application.rb の require を確認する"
    end
  end

  test "使っている Rails のフレームワークを読み込む" do
    LOADED_FRAMEWORKS.each do |framework|
      assert (Object.const_get(framework) rescue nil),
        "#{framework} が読み込まれていない。config/application.rb の require を確認する"
    end
  end

  test "production の設定に cable データベースを持たない" do
    # Action Cable を読み込まない以上、作成・接続・バックアップ・監視の
    # 対象として cable データベースを残さない（ADR 0065）。
    production = Rails.application.config.database_configuration.fetch("production")

    assert_not_includes production.keys, "cable"
    assert_includes production.keys, "queue"
    assert_includes production.keys, "cache"
  end

  test "Rails が読み込まない標準ライブラリを、使う側が宣言する" do
    UNDECLARED_UNLESS_REQUIRED.each do |library, usage|
      users = ruby_sources.select { |path| path.read.match?(usage) }

      assert_not_empty users,
        "#{library} の利用箇所が 1 件もない。目印が実装とずれているか、利用をやめている"

      declaration = /^require ["']#{Regexp.escape(library)}["']$/

      users.each do |path|
        # assert_match は不一致のときに対象の全文を出す。
        # ソース 1 ファイル分の差分が診断を埋めるため、真偽だけを判定する。
        assert path.read.match?(declaration),
          "#{path.relative_path_from(Rails.root)} が #{library} を使いながら宣言していない"
      end
    end
  end

  private
    def ruby_sources
      SOURCE_ROOTS.flat_map { |root| Rails.root.glob("#{root}/**/*.rb") }
    end
end
