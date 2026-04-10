class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
    @user = User.find_or_create_for_google(request.env["omniauth.auth"])

    if @user.persisted?
      unless @user.active?
        flash[:alert] = "Your account has been deactivated. Please contact admin."
        redirect_to new_user_session_path and return
      end

      sign_in_and_redirect @user, event: :authentication
      set_flash_message(:notice, :success, kind: "Google") if is_navigational_format?
    else
      session["devise.google_data"] = request.env["omniauth.auth"].except(:extra)
      flash[:alert] = @user.errors.full_messages.join(", ")
      redirect_to new_user_registration_url
    end
  end

  def failure
    redirect_to new_user_session_path, alert: "Google authentication failed. Please try again."
  end
end
