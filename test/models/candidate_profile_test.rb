require "test_helper"

# 求職者のプロフィールの契約を検証する。
#
# 検証対象は、アカウントとの結び付きと値の規則である。
# 誰が扱えるかは integration のテストが持つ。
class CandidateProfileTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email_address: "member@example.com", password: "correct horse battery")
  end

  test "表示名を持つプロフィールを作成できる" do
    assert_predicate build, :valid?
  end

  test "表示名の前後の空白を取り除く" do
    assert_equal "山田 太郎", build(display_name: "  山田 太郎 ").display_name
  end

  test "表示名のないプロフィールを作れない" do
    assert_not build(display_name: nil).valid?
    assert_not build(display_name: "   ").valid?
  end

  test "上限を超える表示名を拒否する" do
    assert_not build(display_name: "a" * (CandidateProfile::DISPLAY_NAME_MAX_LENGTH + 1)).valid?
  end

  test "上限を超える自己紹介を拒否する" do
    assert_not build(introduction: "a" * (CandidateProfile::INTRODUCTION_MAX_LENGTH + 1)).valid?
  end

  test "表示名以外は未入力でよい" do
    # ほかは後から埋められる。
    assert_predicate build(introduction: nil, location: nil, desired_occupation: nil), :valid?
  end

  test "同じアカウントに 2 つのプロフィールを作れない" do
    build.save!

    assert_not build.valid?
  end

  test "検証を迂回した重複をデータベースが拒否する" do
    build.save!

    assert_raises(ActiveRecord::RecordNotUnique) do
      CandidateProfile.insert_all!([ {
        user_id: @user.id,
        display_name: "別の名前",
        created_at: Time.current,
        updated_at: Time.current
      } ])
    end
  end

  test "アカウントを削除するとプロフィールも消える" do
    build.save!

    assert_difference -> { CandidateProfile.count }, -1 do
      @user.destroy
    end
  end

  test "アカウントを後から付け替えられない" do
    # 付け替えられると、他人のプロフィールを自分のものにできる。
    profile = build.tap(&:save!)
    other = User.create!(email_address: "other@example.com", password: "correct horse battery")

    assert_raises(ActiveRecord::ReadonlyAttributeError) do
      profile.update!(user_id: other.id)
    end
  end

  test "採用の判断に使ってはならない情報を持たない" do
    # 生年月日・性別・顔写真は、最初から保持しない。
    %w[birth_date birthday gender sex photo avatar].each do |column|
      assert_not CandidateProfile.column_names.include?(column), "#{column} を持っている"
    end
  end

  private
    def build(overrides = {})
      CandidateProfile.new({ user: @user, display_name: "山田 太郎" }.merge(overrides))
    end
end
