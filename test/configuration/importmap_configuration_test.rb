require "test_helper"

# ブラウザーへ配る JavaScript の一覧を契約として固定する（ADR 0068）。
#
# 検証対象は importmap が配る項目の集合であり、各モジュールの中身ではない。
#
# ここを固定しないと、使っていない依存が静かに戻る。
# pin を 1 行足しても画面は動く。動くから気付かない。
# 気付かないまま費用を払うのは、画面を開く人の回線と端末である。
class ImportmapConfigurationTest < ActionDispatch::IntegrationTest
  # 配ってよい項目。足すときは、何に使うかを ADR か Issue へ書いてから足す。
  #
  #   application            自前のエントリーポイント
  #   @hotwired/turbo-rails  Turbo Drive。turbo_confirm を使っている
  DECLARED_PACKAGES = %w[application @hotwired/turbo-rails].freeze

  test "importmap は自前のエントリーポイントと Turbo だけを配る" do
    assert_equal DECLARED_PACKAGES.to_set,
      Rails.application.importmap.packages.keys.to_set
  end

  test "importmap はディレクトリを走査しない" do
    # pin_all_from "app/javascript/controllers" は、controller を 1 つも
    # 持たないまま残っていた（ADR 0068）。走査する対象が空でも、
    # 走査する側のモジュールは配られる。
    assert_empty Rails.application.importmap.directories
  end

  test "Stimulus を配らない" do
    # 宣言の一覧だけでは、名前を変えて戻したときに気付けない。
    # 実際に配られる JSON を見る。
    get localized_root_path(locale: :ja)
    assert_response :success

    imports = rendered_importmap.fetch("imports")

    assert_equal DECLARED_PACKAGES.to_set, imports.keys.to_set
    assert_empty imports.values.grep(/stimulus/i),
      "importmap が Stimulus の資産を配っている"
  end

  test "app/javascript に controllers を持たない" do
    assert_not Rails.root.join("app/javascript/controllers").exist?,
      "controller を書き始めるときは、ADR 0068 の判断を更新してから足す"
  end

  private
    def rendered_importmap
      json = css_select("script[type='importmap']").first
      assert json, "画面が importmap を出していない"

      JSON.parse(json.text)
    end
end
