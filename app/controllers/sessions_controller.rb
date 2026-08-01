class SessionsController < ApplicationController
  def new
  end

  def create
    # authenticate_by は、メールアドレスが存在しない場合でもパスワードの照合と
    # 同じだけの時間をかける。存在の有無を応答時間から読み取れないようにするため、
    # find_by と authenticate を自分で組み合わせない。
    user = User.authenticate_by(email_address: params[:email_address], password: params[:password])

    if user
      start_new_session_for(user)

      redirect_to localized_root_path(locale: I18n.locale)
    else
      # 失敗の理由を区別しない。「登録がない」と「パスワードが違う」を分けて伝えると、
      # ログイン画面がメールアドレスの登録有無を調べる道具になる。
      #
      # 入力されたパスワードは画面へ書き戻さない。
      @email_address = params[:email_address]

      flash.now[:alert] = t(".failure")
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    terminate_session

    redirect_to localized_root_path(locale: I18n.locale)
  end
end
