# frozen_string_literal: true

# リクエストの本文の大きさに上限を設ける。
#
# Puma にも Rack にも既定の上限はない。
# 上限がないと、確認済みのアカウントが 1 つあれば、
# 拒否されると分かっている大きさの本文を送り続けてディスクを埋められる。
#
# 添付の大きさはモデルが検証する（ADR 0031）。
# しかし検証が動くのは、**Rack が本文の全体を一時ファイルへ書き終えた後**である。
# モデルの検証だけでは、書かせないことができない。
#
# 413 は例外ではないため exceptions_app を通らない。
# ほかのエラー画面と同じく、public/ の静的 HTML をそのまま返す（ADR 0003）。
# 方針は docs/decisions/0063-request-size-limits.md を正本とする。
class RequestBodyLimit
  # 受け取る本文の上限。
  #
  # 添付の上限（10 MB、ADR 0031）へ、multipart の枠と同時に送られる項目の分を足す。
  # 値そのものに強い根拠はない。添付の上限を上げるときは、こちらも上げる。
  MAX_BYTES = 20 * 1024 * 1024

  # 表示する言語は、ほかのエラー画面と同じく URL の先頭のセグメントで決める。
  DEFAULT_LOCALE = "ja"
  AVAILABLE_LOCALES = %w[ja en].freeze

  def initialize(app, max_bytes: MAX_BYTES)
    @app = app
    @max_bytes = max_bytes
  end

  def call(env)
    return too_large(env) if over_limit?(env)

    @app.call(env)
  end

  private
    # 申告された大きさだけを見る。
    #
    # 本文を読んでから数えると、数え終えた時点ですでに受け取っている。
    # 申告のない本文（chunked）はここでは止まらない。
    # その場合の上限は前段（逆プロキシ、Puma）が持つ
    # （docs/development/reverse-proxy.md）。
    def over_limit?(env)
      content_length = env["CONTENT_LENGTH"]

      content_length.present? && content_length.to_i > @max_bytes
    end

    def too_large(env)
      body = page(locale_for(env))

      [ 413,
        { "content-type" => "text/html; charset=utf-8", "content-length" => body.bytesize.to_s },
        [ body ] ]
    end

    def locale_for(env)
      segment = env["PATH_INFO"].to_s.split("/", 3)[1]

      AVAILABLE_LOCALES.include?(segment) ? segment : DEFAULT_LOCALE
    end

    # 既定のロケールは拡張子を持たないファイルを正本とする
    # （ActionDispatch::PublicExceptions と同じ規則）。
    def page(locale)
      @pages ||= {}
      @pages[locale] ||= begin
        name = locale == DEFAULT_LOCALE ? "413.html" : "413.#{locale}.html"

        Rails.public_path.join(name).read
      end
    end
end
