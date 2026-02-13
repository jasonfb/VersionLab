class OnboardingController < ApplicationController
  layout "devise"

  def new
  end

  def check_email
    email = params[:email].to_s.strip.downcase

    if User.exists?(email: email)
      redirect_to onboarding_path, alert: "#{email} is already registered. Please ask your organization's admin to add you, or log in."
    else
      redirect_to onboarding_signup_path(email: email)
    end
  end

  def signup
    @email = params[:email].to_s.strip
    @user = User.new(email: @email)
  end

  def create
    @email = onboarding_params[:email].to_s.strip.downcase

    ActiveRecord::Base.transaction do
      @user = User.new(
        email: @email,
        password: onboarding_params[:password],
        password_confirmation: onboarding_params[:password_confirmation]
      )

      unless @user.save
        render :signup, status: :unprocessable_entity and return
      end

      account = Account.create!(name: onboarding_params[:account_name])
      AccountUser.create!(user: @user, account: account, is_owner: true)
    end

    sign_in(@user)
    redirect_to "/app"
  end

  private

  def onboarding_params
    params.require(:onboarding).permit(:email, :account_name, :password, :password_confirmation)
  end
end
