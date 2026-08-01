class RegistrationsController < ApplicationController
  def new
    @user = User.new
  end

  def create
    @user = User.new(registration_params)

    if @user.save
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
