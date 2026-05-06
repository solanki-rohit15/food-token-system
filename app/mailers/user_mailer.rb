class UserMailer < ApplicationMailer
  default from: ENV.fetch("MAILER_SENDER", "noreply@foodtoken.com")

  def invitation_email(user, temp_password)
    @user          = user
    @temp_password = temp_password
    @login_url = Rails.application.routes.url_helpers.new_user_session_url(
      host: ENV.fetch("APP_HOST", "localhost:3000")
    )
    mail(to: @user.email, subject: "Welcome to FoodToken — Your Login Details")
  end
end
