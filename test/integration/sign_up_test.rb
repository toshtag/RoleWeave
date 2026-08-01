require "test_helper"

# アカウント作成の契約を検証する。
#
# 検証対象は、作成の成否と、失敗したときに何が画面へ残るかである。
# メールアドレスとパスワードの規則そのものは user_test が持つ。
class SignUpTest < ActionDispatch::IntegrationTest
  EMAIL_ADDRESS = "member@example.com".freeze
  PASSWORD = "correct horse battery".freeze

  test "アカウントを作成できる" do
    assert_difference -> { User.count }, 1 do
      sign_up
    end

    assert_redirected_to localized_root_path(locale: :ja)
  end

  test "作成した直後からログイン状態になる" do
    # もう一度ログイン操作をさせると、いま決めたばかりのパスワードを入力し直すことになる。
    assert_difference -> { Session.count }, 1 do
      sign_up
    end

    follow_redirect!

    assert_select "header .site-header__account-name", text: EMAIL_ADDRESS
  end

  test "英語の URL でも作成できる" do
    sign_up(locale: :en)

    assert_redirected_to localized_root_path(locale: :en)
  end

  test "重複するメールアドレスでは作成できない" do
    User.create!(email_address: EMAIL_ADDRESS, password: PASSWORD)

    assert_no_difference -> { User.count } do
      sign_up
    end

    assert_response :unprocessable_content
  end

  test "大文字小文字だけが違うメールアドレスでも作成できない" do
    User.create!(email_address: EMAIL_ADDRESS, password: PASSWORD)

    assert_no_difference -> { User.count } do
      sign_up(email_address: EMAIL_ADDRESS.upcase)
    end
  end

  test "形式が不正なメールアドレスでは作成できない" do
    assert_no_difference -> { User.count } do
      sign_up(email_address: "member")
    end

    assert_response :unprocessable_content
  end

  test "短すぎるパスワードでは作成できない" do
    assert_no_difference -> { User.count } do
      sign_up(password: "a" * (User::PASSWORD_MIN_LENGTH - 1))
    end

    assert_response :unprocessable_content
  end

  test "確認用の入力が一致しないと作成できない" do
    assert_no_difference -> { User.count } do
      sign_up(password_confirmation: "#{PASSWORD}x")
    end

    assert_response :unprocessable_content
  end

  test "失敗したときに入力したメールアドレスを残す" do
    sign_up(password: "short")

    assert_select "input[name=?][value=?]", "user[email_address]", EMAIL_ADDRESS
  end

  test "失敗したときに入力したパスワードを画面へ書き戻さない" do
    sign_up(password: "short password")

    assert_select "input[type=password][value]", count: 0
    assert_not_includes response.body, "short password"
  end

  test "誤りの説明を入力欄と結び付ける" do
    # 近くに置くだけでは、読み上げでどの欄の説明かが分からない。
    sign_up(email_address: "member")

    error_id = css_select("input[name='user[email_address]']").first["aria-describedby"]

    assert error_id.present?, "誤りの説明が入力欄と結び付いていない"
    assert_select "##{error_id}", count: 1
  end

  test "誤りのない項目へ解決できない参照を残さない" do
    # 存在しない id を aria-describedby へ書くと、支援技術が解決できない参照になる。
    sign_up(email_address: "member")

    referenced_ids = css_select("input[aria-describedby]").flat_map { |input| input["aria-describedby"].split }

    referenced_ids.uniq.each do |id|
      assert_select "##{id}", count: 1, message: "#{id} を参照しているが要素がない"
    end
  end

  test "登録画面を日本語と英語で表示する" do
    I18n.available_locales.each do |locale|
      get new_registration_path(locale: locale)

      assert_response :success
      assert_select "html[lang=?]", locale.to_s
      assert_select "main h1", text: I18n.t("registrations.new.title", locale: locale)
    end
  end

  test "登録画面の入力欄にラベルが対応づく" do
    get new_registration_path(locale: :ja)

    %w[user_email_address user_password user_password_confirmation].each do |field|
      assert_select "label[for=?]", field, count: 1
      assert_select "input##{field}", count: 1
    end
  end

  test "ログイン画面と登録画面が相互にたどれる" do
    get new_session_path(locale: :ja)
    assert_select "main a[href=?]", new_registration_path(locale: :ja)

    get new_registration_path(locale: :ja)
    assert_select "main a[href=?]", new_session_path(locale: :ja)
  end

  test "未ログイン時にアカウント作成の導線を出す" do
    get localized_root_path(locale: :ja)

    assert_select "header a[href=?]", new_registration_path(locale: :ja)
  end

  test "ログイン中はアカウント作成の導線を出さない" do
    sign_up
    follow_redirect!

    assert_select "header a[href=?]", new_registration_path(locale: :ja), count: 0
  end

  private
    def sign_up(locale: :ja, email_address: EMAIL_ADDRESS, password: PASSWORD, password_confirmation: nil)
      post registration_path(locale: locale), params: {
        user: {
          email_address: email_address,
          password: password,
          password_confirmation: password_confirmation || password
        }
      }
    end
end
