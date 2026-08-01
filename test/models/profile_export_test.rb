require "test_helper"

# 自分のデータの持ち出しの契約を検証する。
#
# 検証対象は、何が出て何が出ないかである。
# 出してはならないものが混ざると、渡った先で悪用されうる。
class ProfileExportTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email_address: "member@example.com", password: "correct horse battery")
    @user.confirm
  end

  test "アカウントの情報が出る" do
    export = ProfileExport.new(@user).to_h

    assert_equal "member@example.com", export[:account]["email_address"]
    assert_not_nil export[:account]["confirmed_at"]
  end

  test "パスワードのハッシュを含めない" do
    # 渡った先で総当たりの材料になる。
    json = ProfileExport.new(@user).to_json

    assert_no_match(/password/, json)
    assert_no_match(/#{Regexp.escape(@user.password_digest)}/, json)
  end

  test "セッションと token を含めない" do
    @user.sessions.create!

    json = ProfileExport.new(@user).to_json

    assert_no_match(/session/i, json)
    assert_no_match(/token/i, json)
  end

  test "運営者かどうかを含めない" do
    # このサーバーの運用の情報であり、本人のデータではない。
    @user.update!(operator: true)

    assert_no_match(/operator/, ProfileExport.new(@user).to_json)
  end

  test "プロフィールがなくてもエクスポートできる" do
    export = ProfileExport.new(@user).to_h

    assert_nil export[:candidate_profile]
    assert_not_nil export[:account]
  end

  test "プロフィールと従属する情報が出る" do
    fill_profile

    export = ProfileExport.new(@user).to_h
    profile = export[:candidate_profile]

    assert_equal "山田 太郎", profile["display_name"]
    assert_equal "株式会社サンプル", profile["work_experiences"].sole["organization_name"]
    assert_equal "サンプル大学", profile["educations"].sole["school_name"]
    assert_equal "Ruby", profile["skills"].sole["name"]
    assert_equal "full_time", profile["desired_condition"]["employment_type"]
  end

  test "公開範囲の設定が出る" do
    # 何を誰へ見せる設定だったかも、本人のデータである。
    fill_profile
    @user.candidate_profile.update!(visibility: "all_organizations", documents_visible: true)

    profile = ProfileExport.new(@user).to_h[:candidate_profile]

    assert_equal "all_organizations", profile["visibility"]
    assert profile["documents_visible"]
  end

  test "添付は名前と大きさと形式だけが出る" do
    fill_profile
    attach_resume

    document = ProfileExport.new(@user).to_h[:candidate_profile]["documents"].sole

    assert_equal "resume", document["kind"]
    assert_equal "resume.pdf", document["filename"]
    assert_equal "application/pdf", document["content_type"]
    assert_operator document["byte_size"], :>, 0
    assert_not document.key?("data")
  end

  test "組織の所属が出る" do
    Organization.create_with_owner!(name: "サンプル株式会社", user: @user)

    membership = ProfileExport.new(@user).to_h[:memberships].sole

    assert_equal "サンプル株式会社", membership["organization_name"]
    assert_equal "owner", membership["role"]
    assert_not_nil membership["joined_at"]
  end

  test "出す列と出さない列で、対象の表の列をすべて説明している" do
    # 列を足したときに、黙って出る／黙って出ないの両方を避ける。
    # 落ちた場合は、新しい列をどちらかへ足す。出さないなら理由も書く。
    { "users" => User, "candidate_profiles" => CandidateProfile }.each do |table, model|
      described = ProfileExport::EXPORTED_COLUMNS.fetch(table) +
                  ProfileExport::EXCLUDED_COLUMNS.fetch(table).keys

      assert_equal model.column_names.sort, described.sort, "#{table} の列"
    end
  end

  test "出さない列には理由が書かれている" do
    ProfileExport::EXCLUDED_COLUMNS.each_value do |columns|
      columns.each do |column, reason|
        assert_not_empty reason.to_s, "#{column} の理由"
      end
    end
  end

  private
    def fill_profile
      profile = @user.create_candidate_profile!(display_name: "山田 太郎")
      profile.work_experiences.create!(
        organization_name: "株式会社サンプル", position: "人事", started_on: Date.new(2020, 4, 1)
      )
      profile.educations.create!(school_name: "サンプル大学", started_on: Date.new(2016, 4, 1))
      profile.skills.create!(name: "Ruby")
      profile.create_desired_condition!(employment_type: "full_time")
    end

    def attach_resume
      @user.candidate_profile.resume.attach(
        io: File.open(Rails.root.join("test/fixtures/files/resume.pdf")),
        filename: "resume.pdf",
        content_type: "application/pdf"
      )
    end
end
