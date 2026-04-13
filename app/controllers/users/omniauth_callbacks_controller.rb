class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
    @user = User.from_google_oauth(request.env["omniauth.auth"])

    unless @user.active?
      flash[:alert] = "Your account has been deactivated. Please contact admin."
      return redirect_to new_user_session_path
    end

    sign_in_and_redirect @user, event: :authentication
    set_flash_message(:notice, :success, kind: "Google") if is_navigational_format?

  rescue RuntimeError => e
    # Domain restriction or other OAuth error
    flash[:alert] = e.message
    redirect_to new_user_session_path
  rescue StandardError => e
    Rails.logger.error "OAuth error: #{e.class} — #{e.message}"
    flash[:alert] = "Google sign-in failed. Please try again."
    redirect_to new_user_session_path
  end

  def failure
    redirect_to new_user_session_path, alert: "Google authentication failed. Please try again."
  end
end
