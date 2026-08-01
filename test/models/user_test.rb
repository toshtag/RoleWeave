require "test_helper"

# アカウントの識別子の契約を検証する。
#
# 検証対象はメールアドレスの正規化と一意性であり、
# メールアドレスの到達性や、実在する書式の網羅ではない。
class UserTest < ActiveSupport::TestCase
  test "メールアドレスを持つアカウントを作成できる" do
    user = User.create(email_address: "member@example.com")

    assert_predicate user, :persisted?
  end

  test "メールアドレスの前後の空白を取り除く" do
    user = User.new(email_address: "  member@example.com\t")

    assert_equal "member@example.com", user.email_address
  end

  test "メールアドレスを小文字へそろえる" do
    user = User.new(email_address: "Member@Example.COM")

    assert_equal "member@example.com", user.email_address
  end

  test "正規化を検索条件へも適用する" do
    # 保存だけを正規化すると、登録はできるがそのままでは見つからない状態が生まれる。
    User.create!(email_address: "member@example.com")

    assert User.find_by(email_address: " Member@Example.COM "), "正規化した値で検索できない"
  end

  test "同じメールアドレスの登録を拒否する" do
    User.create!(email_address: "member@example.com")
    duplicate = User.new(email_address: "member@example.com")

    assert_not duplicate.valid?
    assert_includes duplicate.errors.attribute_names, :email_address
  end

  test "大文字小文字だけが違うメールアドレスの登録を拒否する" do
    User.create!(email_address: "member@example.com")

    assert_not User.new(email_address: "MEMBER@EXAMPLE.COM").valid?
  end

  test "前後の空白だけが違うメールアドレスの登録を拒否する" do
    User.create!(email_address: "member@example.com")

    assert_not User.new(email_address: "  member@example.com  ").valid?
  end

  test "検証を迂回した重複の保存をデータベースが拒否する" do
    # 検証だけでは、同時に届いた 2 つの登録の間で重複を防げない。
    # 一意性の最後の担保はデータベース側にある。
    User.create!(email_address: "member@example.com")

    assert_raises(ActiveRecord::RecordNotUnique) do
      # insert_all は競合を黙って読み飛ばす。制約そのものを確かめるため insert_all! を使う。
      User.insert_all!([ { email_address: "member@example.com", created_at: Time.current, updated_at: Time.current } ])
    end
  end

  test "メールアドレスのないアカウントを拒否する" do
    assert_not User.new(email_address: nil).valid?
    assert_not User.new(email_address: "   ").valid?
  end

  test "形式が不正なメールアドレスを拒否する" do
    [ "member", "member@", "@example.com", "member example@example.com" ].each do |email_address|
      assert_not User.new(email_address: email_address).valid?, "#{email_address} を受け入れている"
    end
  end

  test "上限を超える長さのメールアドレスを拒否する" do
    domain = "@example.com"
    local_part = "a" * (User::EMAIL_ADDRESS_MAX_LENGTH - domain.length + 1)

    assert_not User.new(email_address: "#{local_part}#{domain}").valid?
  end

  test "上限と同じ長さのメールアドレスを受け入れる" do
    # 上限そのものを拒否すると、境界の判定が 1 文字ずれていることに気付けない。
    domain = "@example.com"
    local_part = "a" * (User::EMAIL_ADDRESS_MAX_LENGTH - domain.length)

    assert_predicate User.new(email_address: "#{local_part}#{domain}"), :valid?
  end

  test "モデル名と属性名を日本語と英語で提供する" do
    # 辞書がないときは humanize した英語が返る。
    # 値が空でないことだけでは、日本語を提供しているかを判定できない。
    assert_not_equal User.model_name.human(locale: :en),
                     User.model_name.human(locale: :ja)
    assert_not_equal User.human_attribute_name(:email_address, locale: :en),
                     User.human_attribute_name(:email_address, locale: :ja)
  end
end
