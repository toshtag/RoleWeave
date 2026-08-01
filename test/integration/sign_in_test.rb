require "test_helper"

# ログインとログアウトの契約を検証する。
#
# 検証対象は、認証の成否とログイン状態の作り方・消し方である。
# パスワードの保存方式そのものは user_test が持つ。
class SignInTest < ActionDispatch::IntegrationTest
  EMAIL_ADDRESS = "member@example.com".freeze
  PASSWORD = "correct horse battery".freeze

  setup do
    @user = User.create!(email_address: EMAIL_ADDRESS, password: PASSWORD)
  end

  test "正しいメールアドレスとパスワードでログインできる" do
    assert_difference -> { Session.count }, 1 do
      sign_in
    end

    assert_redirected_to localized_root_path(locale: :ja)
    follow_redirect!
    assert_select "header .site-header__account-name", text: EMAIL_ADDRESS
  end

  test "英語の URL でもログインできる" do
    sign_in(locale: :en)

    assert_redirected_to localized_root_path(locale: :en)
  end

  test "誤ったパスワードではログインできない" do
    assert_no_difference -> { Session.count } do
      sign_in(password: "#{PASSWORD}x")
    end

    assert_response :unprocessable_content
    assert_select "header .site-header__account-name", count: 0
  end

  test "存在しないメールアドレスではログインできない" do
    assert_no_difference -> { Session.count } do
      sign_in(email_address: "unknown@example.com")
    end

    assert_response :unprocessable_content
  end

  test "失敗の文言がメールアドレスの登録の有無で変わらない" do
    # 理由を分けて伝えると、ログイン画面がメールアドレスの登録有無を調べる道具になる。
    sign_in(password: "#{PASSWORD}x")
    wrong_password = failure_message

    sign_in(email_address: "unknown@example.com")

    assert_equal wrong_password, failure_message
  end

  test "失敗したときに入力したパスワードを画面へ書き戻さない" do
    sign_in(password: "#{PASSWORD}x")

    assert_select "input[type=password][value]", count: 0
    assert_not_includes response.body, "#{PASSWORD}x"
  end

  test "失敗したときに入力したメールアドレスを残す" do
    # 入力をすべて捨てると、打ち直しのたびに同じ誤りを繰り返す余地が増える。
    sign_in(password: "#{PASSWORD}x")

    assert_select "input[name=email_address][value=?]", EMAIL_ADDRESS
  end

  test "ログアウトするとセッションが消える" do
    sign_in

    assert_difference -> { Session.count }, -1 do
      delete session_path(locale: :ja)
    end

    assert_redirected_to localized_root_path(locale: :ja)
    follow_redirect!
    assert_select "header .site-header__account-name", count: 0
  end

  test "ログアウトを GET で行わない" do
    # GET で状態が変わると、先読みやリンクの巡回だけでログアウトが起こる。
    sign_in

    assert_no_difference -> { Session.count } do
      get session_path(locale: :ja)
    end

    assert_response :not_found
  end

  test "ログアウトの後にログイン状態へ戻らない" do
    sign_in
    delete session_path(locale: :ja)

    get localized_root_path(locale: :ja)

    assert_select "header .site-header__account-name", count: 0
  end

  test "セッションの Cookie を書き換えるとログイン状態にならない" do
    # 署名付き Cookie のため、値を差し替えると復元に失敗する。
    sign_in
    cookies[:session_id] = "#{@user.sessions.first.id}"

    get localized_root_path(locale: :ja)

    assert_select "header .site-header__account-name", count: 0
  end

  test "参照先が消えたセッションをログイン状態として扱わない" do
    sign_in
    Session.delete_all

    get localized_root_path(locale: :ja)

    assert_select "header .site-header__account-name", count: 0
  end

  test "アカウントを削除するとセッションも消える" do
    sign_in

    assert_difference -> { Session.count }, -1 do
      @user.destroy
    end
  end

  test "未ログイン時にログインの導線を出す" do
    get localized_root_path(locale: :ja)

    assert_select "header a[href=?]", new_session_path(locale: :ja)
  end

  test "ログイン画面を日本語と英語で表示する" do
    I18n.available_locales.each do |locale|
      get new_session_path(locale: locale)

      assert_response :success
      assert_select "html[lang=?]", locale.to_s
      assert_select "main h1", text: I18n.t("sessions.new.title", locale: locale)
    end
  end

  test "ログイン画面の入力欄にラベルが対応づく" do
    # ラベルが結び付いていないと、読み上げでどの欄かが分からない。
    get new_session_path(locale: :ja)

    %w[email_address password].each do |field|
      assert_select "label[for=?]", field, count: 1
      assert_select "input##{field}", count: 1
    end
  end

  test "ログイン画面がパスワード管理ソフトへ役割を伝える" do
    get new_session_path(locale: :ja)

    assert_select "input[name=email_address][autocomplete=?]", "username"
    assert_select "input[name=password][autocomplete=?]", "current-password"
  end

  test "無操作の上限を超えたセッションでログイン状態にならない" do
    sign_in
    expire_session(last_active_at: Session::IDLE_TIMEOUT.ago - 1.second)

    get localized_root_path(locale: :ja)

    assert_select "header .site-header__account-name", count: 0
  end

  test "発行からの上限を超えたセッションでログイン状態にならない" do
    # 無操作の上限だけでは、使い続けている限り期限が来ない。
    sign_in
    expire_session(created_at: Session::ABSOLUTE_TIMEOUT.ago - 1.second)

    get localized_root_path(locale: :ja)

    assert_select "header .site-header__account-name", count: 0
  end

  test "期限切れのセッションをその場で削除する" do
    # 残しておくと、判定する場所が増えるたびに期限を見ているかを確認して回ることになる。
    sign_in
    expire_session(last_active_at: Session::IDLE_TIMEOUT.ago - 1.second)

    assert_difference -> { Session.count }, -1 do
      get localized_root_path(locale: :ja)
    end
  end

  test "利用のたびに最終利用時刻を進める" do
    sign_in
    session = @user.sessions.first
    session.update_column(:last_active_at, Session::ACTIVITY_UPDATE_INTERVAL.ago - 1.minute)

    get localized_root_path(locale: :ja)

    assert_operator session.reload.last_active_at, :>, Session::ACTIVITY_UPDATE_INTERVAL.ago
  end

  test "ログインのたびに Cookie の値が変わる" do
    # 既存の Cookie をそのまま使い続けると、ログイン前に仕込まれた値で
    # ログイン後の状態を乗っ取られる。
    sign_in
    first_cookie = cookies[:session_id]

    delete session_path(locale: :ja)
    sign_in

    assert_not_equal first_cookie, cookies[:session_id]
  end

  test "セッションの Cookie が JavaScript から読めない" do
    # 読めると、XSS がそのままログイン状態の乗っ取りになる。
    sign_in

    assert_match(/;\s*HttpOnly/i, set_cookie_header)
  end

  test "セッションの Cookie を別サイトからの遷移で送らない" do
    sign_in

    assert_match(/;\s*SameSite=Lax/i, set_cookie_header)
  end

  test "セッションの Cookie の期限を発行からの上限に合わせる" do
    # permanent（20 年）を使うと、サーバーがすでに無効とみなす Cookie を
    # ブラウザーが持ち続ける。期限があることだけでは、その状態を検出できない。
    sign_in

    expires = set_cookie_header[/;\s*expires=([^;]+)/i, 1]

    assert expires, "Cookie に期限がない"
    assert_in_delta Session::ABSOLUTE_TIMEOUT.from_now.to_i, Time.parse(expires).to_i, 1.day.to_i
  end

  private
    def sign_in(locale: :ja, email_address: EMAIL_ADDRESS, password: PASSWORD)
      post session_path(locale: locale), params: { email_address: email_address, password: password }
    end

    def expire_session(attributes)
      @user.sessions.first.update_columns(attributes)
    end

    def failure_message
      css_select(".form-error").first&.text&.strip
    end

    def set_cookie_header
      Array(response.headers["set-cookie"]).find { |header| header.start_with?("session_id=") }.to_s
    end
end
