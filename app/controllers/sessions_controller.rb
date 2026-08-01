class SessionsController < ApplicationController
  def new
  end

  def create
    # authenticate_by は、メールアドレスが存在しない場合でもパスワードの照合と
    # 同じだけの時間をかける。存在の有無を応答時間から読み取れないようにするため、
    # find_by と authenticate を自分で組み合わせない。
    user = User.authenticate_by(email_address: params[:email_address], password: params[:password])

    if user
      record_event(:sign_in_succeeded, user: user)
      start_new_session_for(user)

      # 要求していた画面があれば、そこへ戻す。
      # 毎回トップページへ送ると、たどり着きたかった場所を利用者が探し直すことになる。
      redirect_to return_to_after_authentication || localized_root_path(locale: I18n.locale)
    else
      # 失敗も記録する。成功だけを残すと、繰り返された試行が見えない。
      record_event(:sign_in_failed)

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
    record_event(:sign_out, user: current_user, email_address: current_user&.email_address)
    terminate_session

    redirect_to localized_root_path(locale: I18n.locale)
  end

  private
    def record_event(kind, user: nil, email_address: nil)
      AuthenticationEvent.record(
        kind: kind,
        email_address: email_address || params[:email_address],
        user: user,
        request: request
      )
    end
end
