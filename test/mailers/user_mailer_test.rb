require "test_helper"

# 確認メールの契約を検証する。
#
# 検証対象は宛先、言語、URL、含めてはならない情報である。
# 配送そのものと外部サービスの設定は対象にしない。
class UserMailerTest < ActionMailer::TestCase
  PASSWORD = "correct horse battery".freeze

  setup do
    @user = User.create!(email_address: "member@example.com", password: PASSWORD)
  end

  test "登録したメールアドレスへ送る" do
    mail = UserMailer.email_confirmation(@user, locale: :ja)

    assert_equal [ @user.email_address ], mail.to
  end

  test "件名と本文をロケールの言語で書く" do
    # 宛先の言語を推測せず、利用者が選んでいた言語をそのまま使う。
    I18n.available_locales.each do |locale|
      mail = UserMailer.email_confirmation(@user, locale: locale)

      assert_equal I18n.t("user_mailer.email_confirmation.subject", locale: locale), mail.subject
      assert_includes mail.body.to_s, I18n.t("user_mailer.email_confirmation.body", locale: locale)
    end
  end

  test "そのロケールの確認 URL を含む" do
    I18n.available_locales.each do |locale|
      mail = UserMailer.email_confirmation(@user, locale: locale)

      assert_match %r{/#{locale}/confirmation/}, mail.body.to_s
    end
  end

  test "本文の URL で確認できる" do
    # URL を組み立てる場所と、受け取る場所が食い違っていないことを確認する。
    mail = UserMailer.email_confirmation(@user, locale: :ja)
    token = mail.body.to_s[%r{/ja/confirmation/(\S+)}, 1]

    assert_equal @user, User.find_by_token_for(:email_confirmation, token)
  end

  test "平文のパスワードを含めない" do
    # メールは保存も転送もされる。
    mail = UserMailer.email_confirmation(@user, locale: :ja)

    assert_not_includes mail.body.to_s, PASSWORD
  end

  test "呼び出しの後にロケールを残さない" do
    UserMailer.email_confirmation(@user, locale: :en).deliver_now

    assert_equal I18n.default_locale, I18n.locale
  end
end
