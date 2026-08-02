require "csv"

# 求人の CSV 入出力。
#
# 取り込みは外部の識別子（`external_key`）で照合する。
# **1 行の失敗で全体を止めない。**行ごとに数え、失敗の内容を残す。
#
# 書き出す値は、表計算ソフトが数式として解釈しない形へ直す。
# 方針は docs/decisions/0058-csv-integration.md と
# docs/decisions/0061-csv-formula-neutralization.md を正本とする。
class JobPostingCsv
  # 入出力で扱う列。ここに書いていない列は読み書きしない。
  COLUMNS = %w[external_key title description requirements location occupation
               employment_type salary_currency annual_salary_min annual_salary_max].freeze

  # 取り込みで書き換えてよい項目。状態（status）は含めない。
  IMPORTABLE_COLUMNS = (COLUMNS - %w[external_key]).freeze

  # 表計算ソフトが数式として解釈する先頭の文字。
  #
  # CSV そのものは壊れていない。壊れるのは**開く側**であり、
  # 引用符の規則を守るだけでは防げない。
  FORMULA_TRIGGERS = [ "=", "+", "-", "@", "\t", "\r" ].freeze

  # 文字列として扱わせる印。表計算ソフトはこれを値の一部として表示しない。
  TEXT_MARKER = "'".freeze

  # 取り込みで受け付ける大きさと行数。
  #
  # 上限がないと、1 つのファイルでメモリを使い切らせられる。
  # 値そのものに強い根拠はない。求人の 1 件は数 KB であり、
  # 1 万件の取り込みは手作業の移行として十分な規模である。
  # 詳細は docs/decisions/0063-request-size-limits.md を参照する。
  MAX_BYTE_SIZE = 5 * 1024 * 1024
  MAX_ROWS = 10_000

  # 大きすぎる入力。取り込まずに理由を返す。
  class TooLarge < StandardError; end

  def initialize(organization)
    @organization = organization
  end

  def export
    CSV.generate(headers: true) do |csv|
      csv << COLUMNS

      @organization.job_postings.order(:id).each do |job_posting|
        csv << COLUMNS.map { |column| neutralize(job_posting.public_send(column)) }
      end
    end
  end

  # 取り込んだ結果（作成・更新・失敗の件数と、失敗の内容）を返す。
  #
  # 大きすぎる入力は `TooLarge` を投げる。数えた分だけ取り込んで途中で止めない。
  # 半分だけ取り込まれた状態は、再実行しても直せるとは言えない（ADR 0058）。
  def import(source, performed_by: nil)
    raise TooLarge if source.bytesize > MAX_BYTE_SIZE
    # 数える段階で止める。取り込みながら止めると、半分だけ入った状態が残る。
    raise TooLarge if too_many_rows?(source)

    created = 0
    updated = 0
    failures = []

    # 全行を一度に配列へ展開しない。1 行ずつ読む。
    CSV.new(source, headers: true).each.with_index do |row, index|
      result = import_row(row, index)

      case result
      when :created then created += 1
      when :updated then updated += 1
      else failures << result
      end
    end

    IntegrationRun.create!(
      organization: @organization,
      performed_by: performed_by,
      kind: "job_posting_import",
      status: "completed",
      created_count: created,
      updated_count: updated,
      failed_count: failures.size,
      failures: failures.join("\n").presence
    )
  end

  private
    # 行数を数える。上限を超えた時点で数えるのをやめる。
    # 最後まで数えると、上限を確かめるためだけに全体を読むことになる。
    def too_many_rows?(source)
      count = 0

      CSV.new(source, headers: true).each do
        count += 1

        return true if count > MAX_ROWS
      end

      false
    end

    # 1 行を取り込む。失敗しても例外を投げず、理由を返す。
    # 行番号はファイルの行に合わせる（見出しの分だけずらす）。直す人が探せるようにする。
    def import_row(row, index)
      external_key = restore(row["external_key"]).to_s.strip

      return "#{index + 2} 行目: external_key がない" if external_key.blank?

      job_posting = @organization.job_postings.find_by(external_key: external_key)
      creating = job_posting.nil?
      job_posting ||= @organization.job_postings.build(external_key: external_key)

      # 取り込んだ求人は必ず下書きとする。公開は審査の経路を通す（ADR 0017）。
      job_posting.status = "draft" if creating
      job_posting.assign_attributes(attributes_from(row))

      return creating ? :created : :updated if job_posting.save

      "#{index + 2} 行目: #{job_posting.errors.full_messages.to_sentence}"
    rescue StandardError => error
      "#{index + 2} 行目: #{error.class}"
    end

    def attributes_from(row)
      IMPORTABLE_COLUMNS.to_h { |column| [ column, restore(row[column]).presence ] }.compact
    end

    # 開く側で数式にならない形へ直す。
    #
    # 数値の列は数式になりえない。文字列だけを対象にする。
    # 数値へ印を付けると、金額の列が文字列として読まれる。
    def neutralize(value)
      return value unless value.is_a?(String)
      return value unless FORMULA_TRIGGERS.include?(value[0])

      "#{TEXT_MARKER}#{value}"
    end

    # 書き出しで付けた印を取り除く。
    #
    # 印の後ろが数式の文字である場合だけ取り除く。
    # 無条件に取り除くと、`'` から始まる正当な値が壊れる。
    # 対称にしないと、往復のたびに印が増える。
    def restore(value)
      return value unless value.is_a?(String)
      return value unless value.start_with?(TEXT_MARKER) && FORMULA_TRIGGERS.include?(value[1])

      value[1..]
    end
end
