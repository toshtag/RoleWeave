require "test_helper"

# 求人の CSV 入出力の契約を検証する。
#
# 検証対象は、再実行で二重に作られないことと、1 行の失敗が全体を止めないことである。
class CsvIntegrationTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct horse battery".freeze

  HEADER = "external_key,title,description,requirements,location,occupation," \
           "employment_type,salary_currency,annual_salary_min,annual_salary_max".freeze

  setup do
    @owner = User.create!(email_address: "owner@example.com", password: PASSWORD).tap(&:confirm)
    @organization = Organization.create_with_owner!(name: "サンプル株式会社", user: @owner)
    @member = User.create!(email_address: "member@example.com", password: PASSWORD).tap(&:confirm)
    Membership.create!(organization: @organization, user: @member, role: "member")
  end

  test "管理者が CSV を取り込める" do
    sign_in_as(@owner)

    assert_difference -> { JobPosting.count }, 2 do
      post imports_path, params: { file: csv_file(rows: 2) }
    end

    assert_equal %w[draft draft], JobPosting.order(:id).pluck(:status)
  end

  test "同じ CSV を再実行しても求人が増えない" do
    sign_in_as(@owner)
    post imports_path, params: { file: csv_file(rows: 2) }

    assert_no_difference -> { JobPosting.count } do
      post imports_path, params: { file: csv_file(rows: 2) }
    end

    assert_equal 2, IntegrationRun.where(kind: "job_posting_import").count
    assert_equal 2, IntegrationRun.recent.first.updated_count
  end

  test "再実行で内容が更新される" do
    sign_in_as(@owner)
    post imports_path, params: { file: csv_file(rows: 1) }

    post imports_path, params: { file: csv_file(rows: 1, title: "書き換えた題名") }

    assert_equal "書き換えた題名 1", JobPosting.sole.title
  end

  test "external_key のない行は取り込まれない" do
    sign_in_as(@owner)
    body = "#{HEADER}\n,題名だけ,本文,,,,,,,\n"

    assert_no_difference -> { JobPosting.count } do
      post imports_path, params: { file: uploaded(body) }
    end

    assert_match(/external_key/, IntegrationRun.recent.first.failures)
  end

  test "不正な行があっても残りは取り込まれる" do
    # 1 行の失敗で全体を止めない。
    sign_in_as(@owner)
    body = "#{HEADER}\n" \
           "key-1,正しい求人,本文,,,,,,,\n" \
           "key-2,,本文,,,,,,,\n" \
           "key-3,もう 1 件,本文,,,,,,,\n"

    assert_difference -> { JobPosting.count }, 2 do
      post imports_path, params: { file: uploaded(body) }
    end

    run = IntegrationRun.recent.first

    assert_equal 2, run.created_count
    assert_equal 1, run.failed_count
    assert_match(/3 行目/, run.failures)
  end

  test "取り込んだ求人は公開状態にならない" do
    # 公開は審査の経路を通す（ADR 0017）。
    sign_in_as(@owner)
    body = "#{HEADER}\nkey-1,題名,本文,,,,,,,\n"

    post imports_path, params: { file: uploaded(body) }

    assert_equal "draft", JobPosting.sole.status
  end

test "失敗の理由が読める形で残る" do
  # 「何行目が失敗した」だけでは、何を直せばよいか分からない。
  sign_in_as(@owner)
  body = "#{HEADER}\nkey-1,,本文,,,,,,,\n"

  post imports_path, params: { file: uploaded(body) }

  assert_match(/題名/, IntegrationRun.recent.first.failures)
end

test "CSV に状態の列があっても無視する" do
  # CSV が公開の判断を迂回する経路になってはならない。
  sign_in_as(@owner)
  body = "#{HEADER},status\nkey-1,題名,本文,,,,,,,,published\n"

  post imports_path, params: { file: uploaded(body) }

  assert_equal "draft", JobPosting.sole.status
end

  test "管理者が CSV を書き出せる" do
    @organization.job_postings.create!(title: "書き出す求人", description: "本文",
                                       external_key: "key-1", status: "published")
    sign_in_as(@owner)

    get organization_job_posting_export_path(locale: :ja, organization_id: @organization)

    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_match(/\Aattachment;/, response.headers["Content-Disposition"])
    assert_match(/key-1,書き出す求人/, response.body)
  end

  test "一般の所属者は入出力できない" do
    sign_in_as(@member)

    get new_organization_job_posting_import_path(locale: :ja, organization_id: @organization)

    assert_response :not_found

    get organization_job_posting_export_path(locale: :ja, organization_id: @organization)

    assert_response :not_found
  end

  test "他組織の求人を更新できない" do
    outsider = User.create!(email_address: "outsider@example.com", password: PASSWORD).tap(&:confirm)
    other_organization = Organization.create_with_owner!(name: "別の会社", user: outsider)
    others = other_organization.job_postings.create!(title: "他社の求人", description: "本文",
                                                     external_key: "key-1", status: "published")
    sign_in_as(@owner)

    post imports_path, params: { file: csv_file(rows: 1) }

    assert_equal "他社の求人", others.reload.title
    assert_equal 1, @organization.job_postings.count
  end

  test "実行の履歴が残り、画面に出る" do
    sign_in_as(@owner)
    post imports_path, params: { file: csv_file(rows: 1) }

    get new_organization_job_posting_import_path(locale: :ja, organization_id: @organization)

    assert_response :success
    assert_select "main", text: /#{I18n.t("organizations.job_posting_imports.new.history")}/
  end

  test "ファイルがない場合は伝える" do
    sign_in_as(@owner)

    post imports_path

    assert_equal I18n.t("organizations.job_posting_imports.create.missing_file"), flash[:alert]
  end

  test "取り込みの画面を日本語と英語で表示する" do
    sign_in_as(@owner)

    I18n.available_locales.each do |locale|
      get new_organization_job_posting_import_path(locale: locale, organization_id: @organization)

      assert_response :success
      assert_select "main h1",
                    text: I18n.t("organizations.job_posting_imports.new.title", locale: locale)
    end
  end

  private
    def sign_in_as(user)
      post session_path(locale: :ja), params: { email_address: user.email_address, password: PASSWORD }
    end

    def imports_path
      organization_job_posting_imports_path(locale: :ja, organization_id: @organization)
    end

    def csv_file(rows:, title: "取り込んだ求人")
      body = "#{HEADER}\n"
      rows.times { |index| body += "key-#{index + 1},#{title} #{index + 1},本文,,,,,,,\n" }

      uploaded(body)
    end

    def uploaded(body)
      Rack::Test::UploadedFile.new(StringIO.new(body), "text/csv", original_filename: "jobs.csv")
    end
end
