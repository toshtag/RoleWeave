class ConfirmationsController < ApplicationController
  # メールのリンクは GET にしかできない。
  # 状態を変えるが、この経路だけは GET で受ける。詳細は ADR 0008 を参照する。
  def show
    user = User.find_by_token_for(:email_confirmation, params[:token])

    if user
      # すでに確認済みでも失敗にしない。リンクを 2 回たどるのは普通の操作であり、
      # そこで「無効なリンク」と出すと、確認できていないように見える。
      user.confirm

      @confirmed = true
    else
      # token が壊れている、期限切れ、確認先の変更後、のいずれかである。
      # どれであるかを画面で区別しない。区別すると、token を試す手がかりになる。
      @confirmed = false
    end

    render :show, status: @confirmed ? :ok : :unprocessable_content
  end
end
