class AccountsController < ApplicationController
  # ログインとメールアドレスの確認を、この画面の入口条件とする。
  # 順序が重要である。未ログインの相手へ「確認してください」と伝えても意味がない。
  before_action :require_authentication
  before_action :require_confirmed_email

  def show
    @user = current_user
  end
end
