require "test_helper"

# 画像の variant を生成しない状態（ADR 0064）を契約として固定する。
#
# この判断は「何かを足さないこと」で成り立っている。
# 足さないことは、足されても何も落ちないということでもある。
# 実際、variant を呼ぶコードがないため、設定を :vips へ戻しても
# 依存へ image_processing を戻しても、既存のテストは 1 件も落ちない。
# 判断だけが黙って消える経路になるため、ここで固定する。
#
# 検証対象は設定と依存の宣言であり、画像処理の振る舞いではない。
class ActiveStorageVariantProcessorTest < ActiveSupport::TestCase
  test "variant の処理を無効にする" do
    assert_equal :disabled, ActiveStorage.variant_processor

    # :disabled のときに選ばれる変換器を名前で確かめる。
    # 設定値だけを見ると、Active Storage 側が対応を変えたときに気づけない。
    assert_equal ActiveStorage::Transformers::NullTransformer,
      ActiveStorage.variant_transformer
  end

  test "画像処理の backend を依存へ持たない" do
    # image_processing を宣言すると、Active Storage は起動時に backend を解決する。
    # backend が無ければ起動が落ち、あれば実行環境へ libvips または
    # ImageMagick が要る。どちらも、使っていない変換のために払う費用になる。
    #
    # mini_magick と ruby-vips は image_processing 1.14.0 までの必須依存であり、
    # 単独で戻されても Active Storage からは見えないため、個別に確かめる。
    %w[image_processing mini_magick ruby-vips].each do |backend|
      assert_raises(LoadError, "#{backend} が依存に残っている") do
        require backend
      end
    end
  end
end
