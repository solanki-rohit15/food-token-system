class UserMailer < ApplicationMailer
  default from: ENV.fetch("MAILER_FROM", "noreply@foodtoken.company.com")

  def otp_email(user, otp_code)
    @user      = user
    @otp_code  = otp_code
    @expires_in = "10 minutes"
    mail(to: @user.email, subject: "Your FoodToken OTP: #{@otp_code}")
  end

  def invitation_email(user, temp_password)
    @user          = user
    @temp_password = temp_password
    @login_url = Rails.application.routes.url_helpers.new_user_session_url(
      host: ENV.fetch("APP_HOST", "localhost:3000")
    )
    mail(to: @user.email, subject: "Welcome to FoodToken — Your Login Details")
  end

  def token_ready(user, token)
    @user  = user
    @token = token
    mail(to: @user.email, subject: "Your food token is ready!")
  end
end
