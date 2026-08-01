# 利用者が自分のアカウントを削除する経路。
#
# 対象は常にログインしている本人とする。ID を受け取らない。
# 方針は docs/decisions/0033-account-deletion.md を正本とする。
class AccountDeletionsController < ApplicationController
  before_action :require_authentication
  before_action :require_confirmed_email
  before_action :set_account_deletion

  # 何が消えるかを示す確認の画面。
  def show
  end

  def destroy
    # パスワードの再入力を求める。ログイン状態だけで消せるようにすると、
    # 席を離れた端末からそのまま実行できる。
    unless current_user.authenticate(params[:password])
      flash.now[:alert] = t(".invalid_password")

      return render :show, status: :unprocessable_content
    end

    unless @account_deletion.deletable?
      flash.now[:alert] = t(".sole_owner")

      return render :show, status: :unprocessable_content
    end

    @account_deletion.delete!
    terminate_session

    redirect_to localized_root_path(locale: I18n.locale), notice: t(".deleted")
  end

  private
    def set_account_deletion
      @account_deletion = AccountDeletion.new(current_user)
    end
end
