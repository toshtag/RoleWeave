require "test_helper"

# 送り出す守りの設定を固定する。
#
# CSP・CSRF 保護・セッションの Cookie は設定であり、
# 変えられたことに気付く仕組みがないと、静かに緩む。
class SecurityHeadersTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct horse battery".freeze

  test "すべての画面に CSP が出る" do
    [ localized_root_path(locale: :ja), public_job_postings_path(locale: :ja),
      new_session_path(locale: :ja), new_registration_path(locale: :ja) ].each do |path|
      get path

      assert_response :success
      assert_not_nil response.headers["Content-Security-Policy"], "#{path} に CSP がない"
    end
  end

  test "既定の読み込み元を自分自身に限る" do
    get localized_root_path(locale: :ja)

    assert_match(/default-src 'self'/, policy)
  end

  test "埋め込みと object を許さない" do
    get localized_root_path(locale: :ja)

    assert_match(/object-src 'none'/, policy)
    assert_match(/frame-ancestors 'none'/, policy)
  end

  test "インラインのスクリプトと eval を許さない" do
    # 外部のスクリプトを読み込まない構成であり、緩める理由がない。
    get localized_root_path(locale: :ja)

    assert_match(/script-src 'self'/, policy)
    assert_no_match(/script-src[^;]*unsafe-inline/, policy)
    assert_no_match(/unsafe-eval/, policy)
  end

  test "報告だけの動作になっていない" do
    # 報告だけでは、違反があっても実際には防いでいない。
    get localized_root_path(locale: :ja)

    assert_nil response.headers["Content-Security-Policy-Report-Only"]
  end

  test "CSP の下でも主要な画面が壊れない" do
    user = User.create!(email_address: "member@example.com", password: PASSWORD).tap(&:confirm)
    post session_path(locale: :ja), params: { email_address: user.email_address, password: PASSWORD }

    [ new_profile_path(locale: :ja), organizations_path(locale: :ja), account_path(locale: :ja) ].each do |path|
      get path

      assert_response :success
    end
  end

  test "CSRF 保護が有効である" do
    # トークンのない POST を受け付けない。
    with_forgery_protection do
      post session_path(locale: :ja), params: { email_address: "member@example.com", password: PASSWORD }

      assert_response :unprocessable_content
    end
  end

  test "セッションの Cookie が httponly と same_site を持つ" do
    user = User.create!(email_address: "member@example.com", password: PASSWORD).tap(&:confirm)

    post session_path(locale: :ja), params: { email_address: user.email_address, password: PASSWORD }

    set_cookie = response.headers["Set-Cookie"].to_s

    assert_match(/session_id=/, set_cookie)
    assert_match(/HttpOnly/i, set_cookie)
    assert_match(/SameSite=Lax/i, set_cookie)
  end

  private
    def policy
      response.headers["Content-Security-Policy"].to_s
    end

    def with_forgery_protection
      original = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true

      yield
    ensure
      ActionController::Base.allow_forgery_protection = original
    end
end
