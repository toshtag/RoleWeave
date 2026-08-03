require "test_helper"

# リポジトリに、実行されない生成物を残さない契約を検証する。
#
# 生成物は「動くもの」に見える。route を持たないテンプレート、
# 規則を 1 つも定義しない初期化ファイル、空のディレクトリは、
# いずれもテストを落とさない。落とさないまま、読む側の対象を増やす。
#
# 個別の path を並べるのではなく、構造で書く。
# 一覧にすると、次に増えたものが対象から漏れる。
class RepositoryLayoutTest < ActiveSupport::TestCase
  # controller にも mailer にも対応しないが、Rails の規約が意味を与えるもの。
  CONVENTIONAL_VIEW_DIRECTORIES = %w[layouts shared].freeze

  test "描画する経路を持たないテンプレートを置かない" do
    # app/views/pwa/ は、route が 2 行ともコメントアウトされたまま残っていた。
    # 到達できないテンプレートは、実装の一部として読まれるが実行されない。
    orphans = view_directories.reject do |directory|
      CONVENTIONAL_VIEW_DIRECTORIES.include?(directory) ||
        Rails.root.join("app/controllers/#{directory}_controller.rb").exist? ||
        Rails.root.join("app/mailers/#{directory}.rb").exist?
    end

    assert_empty orphans,
      "描画する controller も mailer も無いテンプレートのディレクトリがある: #{orphans.inspect}"
  end

  test "実行される行を持たない初期化ファイルを置かない" do
    # config/initializers/inflections.rb は、17 行すべてがコメントだった。
    # 初期化ファイルは「ここに何かある」という表明として読まれる。
    empty = Rails.root.glob("config/initializers/*.rb").reject { |path| executable_lines?(path) }

    assert_empty empty.map { |path| path.relative_path_from(Rails.root).to_s },
      "コメントだけの初期化ファイルがある。設定を足すときにファイルごと足す"
  end

  test "スクリプトの置き場所を scripts/ だけにする" do
    # Rails が作る script/ は .keep だけを持っていた。
    # 1 文字違いの行き先が 2 つあると、次に足す人がどちらへ置くかを選べない。
    assert_not Rails.root.join("script").exist?,
      "script/ が復活している。スクリプトは scripts/ へ置く"

    assert_not_empty Rails.root.glob("scripts/*")
  end

  private
    # 拡張子で絞らない。落とした app/views/pwa/service-worker.js は .erb ではなく、
    # .erb だけを見る検査では、同じものが戻っても気付けない。
    def view_directories
      Rails.root.glob("app/views/**/*")
        .select(&:file?)
        .map { |path| path.dirname.relative_path_from(Rails.root.join("app/views")).to_s }
        .uniq
    end

    # コメントと空行を除いて、1 行でも残るか。
    def executable_lines?(path)
      path.readlines.any? { |line| line.strip.present? && !line.strip.start_with?("#") }
    end
end
