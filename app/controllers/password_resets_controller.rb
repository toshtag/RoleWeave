class PasswordResetsController < ApplicationController
  before_action :set_user_from_token, only: %i[edit update]

  def new
  end

  def create
    user = User.find_by(email_address: params[:email_address])

    # 登録がなければ何も送らない。応答は登録の有無で変えない。
    # 区別すると、この画面が登録済みのメールアドレスを調べる道具になる。
    UserMailer.password_reset(user, locale: I18n.locale).deliver_later if user

    render :create
  end

  def edit
  end

  def update
    if @user.update(password_params)
      # パスワードを変えたら、そのアカウントのセッションをすべて破棄する。
      # 変更の理由が乗っ取りだった場合、残したままでは相手が居座り続ける。
      @user.sessions.destroy_all

      # 自動ではログインしない。新しいパスワードで入れることを、
      # 利用者自身がその場で確かめられる状態にする。
      redirect_to new_session_path(locale: I18n.locale), notice: t(".success")
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_user_from_token
      @user = User.find_by_token_for(:password_reset, params[:token])

      # token が壊れている、期限切れ、使用済みのいずれかである。
      # どれであるかを画面で区別しない。区別すると、token を試す手がかりになる。
      render :invalid, status: :unprocessable_content unless @user
    end

    def password_params
      params.expect(user: %i[password password_confirmation])
    end
end
