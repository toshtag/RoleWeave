class UserMailer < ApplicationMailer
  # メールアドレスの確認を依頼する。
  #
  # 表示言語の正本は URL とする契約（ADR 0001）はメールでも維持する。
  # 宛先の言語を推測せず、登録した画面のロケールをそのまま使う。
  def email_confirmation(user, locale:)
    @user = user
    @confirmation_url = confirmation_url(
      locale: locale,
      token: user.generate_token_for(:email_confirmation)
    )
    @expires_in_hours = User::EMAIL_CONFIRMATION_EXPIRES_IN.in_hours.to_i

    I18n.with_locale(locale) do
      mail to: user.email_address, subject: t(".subject")
    end
  end
end
