require "test_helper"

# モデルが公開しているメソッドが、どこかから呼ばれていることを検証する。
#
# 呼ばれないメソッドはテストを落とさない。落とさないまま、
# 読む側の対象と、変更するときに考える対象を増やす。
#
# IntegrationRun#processed_count は、3 つの件数を足した合計を返しながら、
# 呼び出しが 1 件も無かった。合計を出す画面が無く、
# 「成功と失敗を足した数」を何と呼ぶかも決まっていなかった。
#
# 検査は読み込んだクラスではなく**ソースの def** を見る。
# instance_methods(false) には Rails が生成する
# _run_*_callbacks や autosave_associated_records_for_* が含まれ、
# 除外の一覧が実装より長くなる。
#
# **検査していない範囲**（検査済みとして扱わない）:
#
#   private のメソッド     呼び出し元が同じクラスにあり、この検査では追えない
#   send による動的な呼出   名前を組み立てて呼ぶ形は、文字列の一致では追えない
#   app/models 以外        controller・helper・lib は対象にしていない
class UnreferencedMethodTest < ActiveSupport::TestCase
  SOURCE_GLOBS = %w[
    app/**/*.rb app/**/*.erb lib/**/*.rb lib/**/*.rake
    config/**/*.rb config/**/*.yml db/**/*.rb test/**/*.rb
  ].freeze

  test "モデルが公開するメソッドは、どこかから呼ばれている" do
    unreferenced = Rails.root.glob("app/models/**/*.rb").sort.flat_map do |path|
      public_method_names(path).reject { |name| referenced_elsewhere?(name) }
        .map { |name| "#{path.relative_path_from(Rails.root)}##{name}" }
    end

    assert_empty unreferenced,
      "呼び出しの無い公開メソッドがある。使う場所を足すか、メソッドごと落とす"
  end

  private
    # private より前に現れる def だけを対象にする。
    def public_method_names(path)
      source = path.read
      boundary = source.index(/^\s*private\b/) || source.length

      source[0...boundary].scan(/^\s*def (?:self\.)?([a-z_][a-zA-Z0-9_]*[?!]?)/).flatten
    end

    # 定義そのもの（1 件）以外に現れるか。
    #
    # 末尾の ? と ! は、述語と破壊的の対を別名として数えないために外す。
    def referenced_elsewhere?(name)
      pattern = /\b#{Regexp.escape(name.sub(/[?!]\z/, ""))}[?!]?\b/

      sources.sum { |text| text.scan(pattern).size } > 1
    end

    def sources
      @sources ||= SOURCE_GLOBS.flat_map { |glob| Rails.root.glob(glob) }.uniq.map { |path| without_comments(path.read) }
    end

    # 行まるごとのコメントと ERB のコメントを外す。
    #
    # 外さないと、**このテストの説明コメント自体**が呼び出しとして数えられる。
    # 落としたメソッドの名前を理由として書いた時点で、検査が通ってしまう。
    #
    # 行末のコメントは外さない。#{} の中を巻き添えにするためである。
    # 補間の中の呼び出しを消すと、使っているメソッドを未使用と報告する。
    def without_comments(text)
      text.gsub(/^[ \t]*#.*$/, "").gsub(/<%#.*?%>/m, "")
    end
end
