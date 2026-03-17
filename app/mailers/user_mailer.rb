class UserMailer < ApplicationMailer
  def account_invitation(user, account, invited_by)
    @user = user
    @account = account
    @invited_by = invited_by

    # Generate a password reset token so they can set their password on first login
    raw_token, hashed_token = Devise.token_generator.generate(User, :reset_password_token)
    user.update_columns(
      reset_password_token: hashed_token,
      reset_password_sent_at: Time.current
    )
    @reset_url = edit_user_password_url(reset_password_token: raw_token)

    mail(to: user.email, subject: "You've been added to #{account.name} on VersionLab")
  end
end
