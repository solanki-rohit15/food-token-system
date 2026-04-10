class UserMailer < ApplicationMailer
  default from: ENV.fetch("MAILER_FROM", "noreply@foodtoken.company.com")

  def otp_email(user, otp_code)
    @user     = user
    @otp_code = otp_code
    @expires_in = "10 minutes"
    mail(to: @user.email, subject: "Your FoodToken OTP: #{@otp_code}")
  end

  def invitation_email(user)
    @user      = user
    # Use the correct named route
    @login_url = Rails.application.routes.url_helpers.users_new_otp_url(
      host: ENV.fetch("APP_HOST", "localhost:3000")
    )
    @reset_url = Rails.application.routes.url_helpers.new_user_password_url(
      host: ENV.fetch("APP_HOST", "localhost:3000")
    )
    mail(to: @user.email, subject: "Welcome to FoodToken — #{user.name}")
  end

  def token_ready(user, token)
    @user  = user
    @token = token
    mail(to: @user.email, subject: "Your food token is ready!")
  end

  def redemption_request(user, token, vendor_name)
    @user        = user
    @token       = token
    @vendor_name = vendor_name
    mail(to: @user.email, subject: "Redemption request from #{vendor_name}")
  end
end
