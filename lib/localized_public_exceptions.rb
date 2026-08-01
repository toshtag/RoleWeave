# frozen_string_literal: true

require "action_dispatch/middleware/public_exceptions"

# エラー画面の表示ロケールを、例外が起きた元の URL から決める。
#
# ActionDispatch::ShowExceptions は exceptions app を呼ぶ前に PATH_INFO を
# "/404" や "/500" へ書き換え、元のパスを action_dispatch.original_path へ移す。
# 書き換え後のパスにロケールは残らないため、判定には元のパスを使う。
#
# HTML 本文、status、Content-Type、HEAD、HTML 以外の形式の扱いは
# ActionDispatch::PublicExceptions が持つ。ここではロケールだけを決めて委譲する。
# エラー応答を自前で組み立てると、Rails 側の変更に追随できない箇所が増える。
#
# 方針は docs/decisions/0003-localized-static-error-pages.md を正本とする。
class LocalizedPublicExceptions
  ORIGINAL_PATH = "action_dispatch.original_path"

  def initialize(public_path:, available_locales:, default_locale:)
    @public_exceptions = ActionDispatch::PublicExceptions.new(public_path)
    # 対応ロケールは呼び出し側から受け取る。ここへ言語を書き並べると、
    # 対応言語の増減で I18n の設定とエラー画面の判定が食い違う。
    @locales_by_segment = available_locales.to_h { |locale| [ locale.to_s, locale ] }.freeze
    @default_locale = default_locale
  end

  def call(env)
    # I18n.locale へ直接代入すると、同じスレッドを使う次のリクエストへ
    # エラー画面の言語が残る。適用範囲をこの呼び出しの中だけに閉じる。
    I18n.with_locale(locale_for(env)) do
      @public_exceptions.call(env)
    end
  end

  private
    def locale_for(env)
      # 先頭セグメントだけを見る。パスのどこかに現れる en を拾うと、
      # /ja/en-training のような日本語の URL が英語のエラー画面になる。
      segment = env[ORIGINAL_PATH].to_s.split("/", 3)[1]

      # 受け取った文字列を symbol へ変換して I18n へ渡さない。
      # enforce_available_locales が有効なため、対応外のロケールでは
      # I18n.with_locale 自体が例外になり、エラー画面まで失敗する。
      @locales_by_segment.fetch(segment, @default_locale)
    end
end
