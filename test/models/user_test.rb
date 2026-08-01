require "test_helper"

# アカウントの識別子と秘密の契約を検証する。
#
# 検証対象はメールアドレスの正規化と一意性、
# およびパスワードを復元できない形で保存することである。
# メールアドレスの到達性、実在する書式の網羅、bcrypt の実装そのものは対象にしない。
class UserTest < ActiveSupport::TestCase
  # 検証したい属性だけを各テストで上書きできるよう、有効な値を 1 か所へ置く。
  PASSWORD = "correct horse battery".freeze

  test "メールアドレスとパスワードを持つアカウントを作成できる" do
    user = User.create(attributes)

    assert_predicate user, :persisted?
  end

  test "メールアドレスの前後の空白を取り除く" do
    user = User.new(attributes(email_address: "  member@example.com\t"))

    assert_equal "member@example.com", user.email_address
  end

  test "メールアドレスを小文字へそろえる" do
    user = User.new(attributes(email_address: "Member@Example.COM"))

    assert_equal "member@example.com", user.email_address
  end

  test "正規化を検索条件へも適用する" do
    # 保存だけを正規化すると、登録はできるがそのままでは見つからない状態が生まれる。
    User.create!(attributes)

    assert User.find_by(email_address: " Member@Example.COM "), "正規化した値で検索できない"
  end

  test "同じメールアドレスの登録を拒否する" do
    User.create!(attributes)
    duplicate = User.new(attributes)

    assert_not duplicate.valid?
    assert_includes duplicate.errors.attribute_names, :email_address
  end

  test "大文字小文字だけが違うメールアドレスの登録を拒否する" do
    User.create!(attributes)

    assert_not User.new(attributes(email_address: "MEMBER@EXAMPLE.COM")).valid?
  end

  test "前後の空白だけが違うメールアドレスの登録を拒否する" do
    User.create!(attributes)

    assert_not User.new(attributes(email_address: "  member@example.com  ")).valid?
  end

  test "検証を迂回した重複の保存をデータベースが拒否する" do
    # 検証だけでは、同時に届いた 2 つの登録の間で重複を防げない。
    # 一意性の最後の担保はデータベース側にある。
    User.create!(attributes)

    assert_raises(ActiveRecord::RecordNotUnique) do
      # insert_all は競合を黙って読み飛ばす。制約そのものを確かめるため insert_all! を使う。
      User.insert_all!([ {
        email_address: "member@example.com",
        password_digest: "digest",
        created_at: Time.current,
        updated_at: Time.current
      } ])
    end
  end

  test "メールアドレスのないアカウントを拒否する" do
    assert_not User.new(attributes(email_address: nil)).valid?
    assert_not User.new(attributes(email_address: "   ")).valid?
  end

  test "形式が不正なメールアドレスを拒否する" do
    [ "member", "member@", "@example.com", "member example@example.com" ].each do |email_address|
      assert_not User.new(attributes(email_address: email_address)).valid?,
        "#{email_address} を受け入れている"
    end
  end

  test "上限を超える長さのメールアドレスを拒否する" do
    assert_not User.new(attributes(email_address: email_address_of_length(User::EMAIL_ADDRESS_MAX_LENGTH + 1))).valid?
  end

  test "上限と同じ長さのメールアドレスを受け入れる" do
    # 上限そのものを拒否すると、境界の判定が 1 文字ずれていることに気付けない。
    assert_predicate User.new(attributes(email_address: email_address_of_length(User::EMAIL_ADDRESS_MAX_LENGTH))), :valid?
  end

  test "パスワードを平文で保存しない" do
    user = User.create!(attributes)

    assert_not_equal PASSWORD, user.password_digest
    assert_not_includes user.password_digest, PASSWORD
  end

  test "正しいパスワードで認証が成功する" do
    user = User.create!(attributes)

    assert user.authenticate(PASSWORD), "正しいパスワードで認証できない"
  end

  test "誤ったパスワードで認証が失敗する" do
    user = User.create!(attributes)

    assert_not user.authenticate("#{PASSWORD}x")
  end

  test "同じパスワードでもアカウントごとに保存する値が異なる" do
    # ソルトが効いていないと、同じ digest が並び、
    # 1 つの解読が同じパスワードのアカウント全体へ波及する。
    first = User.create!(attributes)
    second = User.create!(attributes(email_address: "other@example.com"))

    assert_not_equal first.password_digest, second.password_digest
  end

  test "パスワードのないアカウントを拒否する" do
    assert_not User.new(attributes(password: nil)).valid?
    assert_not User.new(attributes(password: "")).valid?
  end

  test "最小長に満たないパスワードを拒否する" do
    assert_not User.new(attributes(password: "a" * (User::PASSWORD_MIN_LENGTH - 1))).valid?
  end

  test "最小長と同じ長さのパスワードを受け入れる" do
    assert_predicate User.new(attributes(password: "a" * User::PASSWORD_MIN_LENGTH)), :valid?
  end

  test "最小長を 12 文字とする" do
    # 値そのものを固定する。定数を基準に書いた境界のテストは、
    # 定数ごと条件を緩める変更を検出できない。根拠は ADR 0006 にある。
    assert_equal 12, User::PASSWORD_MIN_LENGTH
  end

  test "bcrypt が切り捨てる長さのパスワードを拒否する" do
    # 切り捨てを黙って受け入れると、入力の一部が認証に使われない状態になる。
    assert_not User.new(attributes(password: "a" * (User::PASSWORD_MAX_BYTESIZE + 1))).valid?
  end

  test "上限と同じバイト数のパスワードを受け入れる" do
    # 上限そのものを拒否すると、境界の判定が 1 バイトずれていることに気付けない。
    # 上限の値が bcrypt の扱える範囲から外れていることも、ここで検出する。
    assert_predicate User.new(attributes(password: "a" * User::PASSWORD_MAX_BYTESIZE)), :valid?
  end

  test "パスワードの長さを文字数ではなくバイト数で判定する" do
    # 日本語のパスワードは 1 文字が複数バイトになる。
    # 文字数で判定すると、bcrypt が切り捨てる長さを受け入れてしまう。
    password = "あ" * 25

    assert_operator password.length, :<=, User::PASSWORD_MAX_BYTESIZE
    assert_operator password.bytesize, :>, User::PASSWORD_MAX_BYTESIZE
    assert_not User.new(attributes(password: password)).valid?
  end

  test "パスワードに文字種の組み合わせを要求しない" do
    # 組み合わせの強制は、記憶しやすい規則的な変形を誘発するだけで、
    # 長さを伸ばすほどには推測を難しくしない。
    assert_predicate User.new(attributes(password: "a" * User::PASSWORD_MIN_LENGTH)), :valid?
  end

  test "確認用の入力が一致しないパスワードを拒否する" do
    user = User.new(attributes(password_confirmation: "#{PASSWORD}x"))

    assert_not user.valid?
    assert_includes user.errors.attribute_names, :password_confirmation
  end

  test "モデル名と属性名を日本語と英語で提供する" do
    # 辞書がないときは humanize した英語が返る。
    # 値が空でないことだけでは、日本語を提供しているかを判定できない。
    assert_not_equal User.model_name.human(locale: :en),
                     User.model_name.human(locale: :ja)

    %i[email_address password password_confirmation].each do |attribute|
      assert_not_equal User.human_attribute_name(attribute, locale: :en),
                       User.human_attribute_name(attribute, locale: :ja),
                       "#{attribute} の属性名が日英で同じ"
    end
  end

  test "バイト数の上限を超えたことを日本語と英語で伝える" do
    # 既定の文言は文字数を前提にしている。この検証専用の文言を持たないと、
    # 翻訳の解決に失敗するか、単位の違う説明が表示される。
    I18n.available_locales.each do |locale|
      I18n.with_locale(locale) do
        user = User.new(attributes(password: "a" * (User::PASSWORD_MAX_BYTESIZE + 1)))
        user.validate

        assert_not_empty user.errors.full_messages_for(:password), "#{locale} の文言がない"
      end
    end
  end

  private
    def attributes(overrides = {})
      { email_address: "member@example.com", password: PASSWORD }.merge(overrides)
    end

    def email_address_of_length(length)
      domain = "@example.com"

      "#{'a' * (length - domain.length)}#{domain}"
    end
  test "再設定リンクの有効期限を 30 分とする" do
    # 定数を基準に書いた境界のテストは、定数ごと条件を緩める変更を検出できない。
    # 値そのものと、実際に設定された期限の両方を固定する。根拠は ADR 0009 にある。
    assert_equal 30.minutes, User::PASSWORD_RESET_EXPIRES_IN
    assert_equal User::PASSWORD_RESET_EXPIRES_IN, User.new.password_reset_token_expires_in
  end

  test "確認リンクの有効期限を 24 時間とする" do
    assert_equal 24.hours, User::EMAIL_CONFIRMATION_EXPIRES_IN
  end
end
