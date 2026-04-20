class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  UNAUTHORIZED_MESSAGE = "You are not authorized. Please contact admin.".freeze

  skip_before_action :check_location_access, raise: false

  def google_oauth2
    auth = request.env["omniauth.auth"]
    email = auth&.dig("info", "email").to_s.strip.downcase
    Rails.logger.info("[Google OAuth] Callback received email=#{email.inspect} uid=#{auth&.dig('uid').inspect}")

    user = User.from_google_oauth(auth)

    if user.present?
      Rails.logger.info("[Google OAuth] Authorized login user_id=#{user.id} email=#{user.email.inspect}")
      sign_in_and_redirect user, event: :authentication
    else
      Rails.logger.warn("[Google OAuth] Authorization failed email=#{email.inspect}")
      redirect_to new_user_session_path, alert: UNAUTHORIZED_MESSAGE
    end
  rescue StandardError => e
    Rails.logger.error("[Google OAuth] Callback failure: #{e.class} - #{e.message}")
    redirect_to new_user_session_path, alert: UNAUTHORIZED_MESSAGE
  end

  def failure
    error_type = request.env["omniauth.error.type"]
    error = request.env["omniauth.error"]
    strategy = request.env["omniauth.error.strategy"]&.name
    Rails.logger.warn(
      "[Google OAuth] Failure strategy=#{strategy.inspect} error_type=#{error_type.inspect} "\
      "error_class=#{error&.class} error_message=#{error&.message}"
    )
    message = if error_type.to_s == "authenticity_error"
                "Your session expired. Please try signing in with Google again."
              else
                UNAUTHORIZED_MESSAGE
              end

    redirect_to new_user_session_path, alert: message
  end
end
