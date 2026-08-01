class RegistrationsController < ApplicationController
  # 繰り返しの試行を抑える。上限と期間は ApplicationController が持つ。
  rate_limit to: SIGN_UP_ATTEMPT_LIMIT, within: RATE_LIMIT_PERIOD, only: :create,
             with: -> { render_rate_limited }

  def new
    @user = User.new
  end

  def create
    @user = User.new(registration_params)

    if @user.save
      # 確認メールは、登録した画面のロケールで送る。
      # 宛先の言語を推測せず、利用者が選んでいた言語をそのまま使う。
      UserMailer.email_confirmation(@user, locale: I18n.locale).deliver_later

      # 作成した直後にログイン状態にする。もう一度ログイン操作をさせると、
      # いま決めたばかりのパスワードを入力し直すことになる。
      start_new_session_for(@user)

      redirect_to localized_root_path(locale: I18n.locale)
    else
      render :new, status: :unprocessable_content
    end
  end

  private
    def registration_params
      params.expect(user: %i[email_address password password_confirmation])
    end
end
