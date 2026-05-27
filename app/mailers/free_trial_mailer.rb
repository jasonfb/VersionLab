# frozen_string_literal: true

class FreeTrialMailer < ApplicationMailer
  def welcome(user, account)
    @user = user
    @account = account

    # Generate a password reset token so they can set their password on first login
    raw_token, hashed_token = Devise.token_generator.generate(User, :reset_password_token)
    user.update_columns(
      reset_password_token: hashed_token,
      reset_password_sent_at: Time.current
    )
    @setup_url = edit_user_password_url(reset_password_token: raw_token)

    mail(to: user.email, subject: "Welcome to VersionLab — Your Free Trial is Active!")
  end
end
