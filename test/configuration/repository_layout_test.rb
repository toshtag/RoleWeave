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

  # Rails が起動時と db:prepare で読み込むファイル。
  # 存在すれば読まれるため、中身が無くても読み込みの対象に入る。
  LOADED_RUBY_GLOBS = %w[config/initializers/*.rb db/seeds.rb].freeze

  # 中身が ignore されるため、.keep が無いとディレクトリごと消えるもの。
  # .gitignore と .dockerignore が、この一覧を名前で否定している。
  IGNORED_DIRECTORIES_WITH_KEEP = %w[log storage tmp tmp/pids tmp/storage].freeze

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

  test "起動と準備で読み込むファイルが、実行される行を持つ" do
    # config/initializers/inflections.rb は 17 行すべてが、
    # db/seeds.rb は 9 行すべてがコメントだった。
    #
    # どちらも Rails が読み込む経路にある。
    # 読み込む側から見ると「ここに何かある」という表明であり、
    # 中身が生成時の例だけだと、読む人は毎回それを確かめることになる。
    empty = LOADED_RUBY_GLOBS.flat_map { |glob| Rails.root.glob(glob) }
      .reject { |path| executable_lines?(path) }

    assert_empty empty.map { |path| path.relative_path_from(Rails.root).to_s },
      "コメントだけのファイルがある。中身が要るときに、ファイルごと足す"
  end

  test "スクリプトの置き場所を scripts/ だけにする" do
    # Rails が作る script/ は .keep だけを持っていた。
    # 1 文字違いの行き先が 2 つあると、次に足す人がどちらへ置くかを選べない。
    assert_not Rails.root.join("script").exist?,
      "script/ が復活している。スクリプトは scripts/ へ置く"

    assert_not_empty Rails.root.glob("scripts/*")
  end

  test "内容のあるディレクトリに .keep を置かない" do
    # .keep は、Git が空のディレクトリを追跡しないことへの回避策である。
    # 中身が 1 つでもあれば何もしない。それでも読む側は
    # 「ここは空になりうる」と読む。test/integration/ には 55 件のテストがある。
    redundant = Rails.root.glob("**/.keep")
      .reject { |path| ignored_directory?(path.dirname) }
      .select { |path| path.dirname.children.size > 1 }

    assert_empty redundant.map { |path| path.relative_path_from(Rails.root).to_s },
      ".keep が要らないディレクトリにある"
  end

  test "ignore の対象のディレクトリの .keep を残す" do
    # .gitignore と .dockerignore が名前で否定している。
    # 落とすと、その行が指す先が無くなり、ディレクトリも追跡から消える。
    IGNORED_DIRECTORIES_WITH_KEEP.each do |directory|
      assert_path_exists Rails.root.join(directory, ".keep"),
        "#{directory}/.keep は .gitignore と .dockerignore が名前で否定している"
    end
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

    def ignored_directory?(directory)
      IGNORED_DIRECTORIES_WITH_KEEP.include?(directory.relative_path_from(Rails.root).to_s)
    end

    # コメントと空行を除いて、1 行でも残るか。
    def executable_lines?(path)
      path.readlines.any? { |line| line.strip.present? && !line.strip.start_with?("#") }
    end
end
