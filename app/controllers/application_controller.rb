class ApplicationController < ActionController::Base
  include Pundit::Authorization

  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name, :role, :phone])
    devise_parameter_sanitizer.permit(:account_update, keys: [:name, :phone, :avatar_url])
  end

  def after_sign_in_path_for(resource)
    resource.dashboard_path
  end

  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_back(fallback_location: root_path)
  end

  def check_location_access
    # return true unless location_restriction_enabled?

    # unless LocationSetting.check_ip(request.remote_ip)
    #   flash[:alert] = "Access denied: You must be within the office network."
    #   sign_out(current_user)
    #   redirect_to new_user_session_path
    # end
  end

  def current_time_str
    Time.current.strftime("%H:%M")
  end
  helper_method :current_time_str

  private

  def location_restriction_enabled?
    LocationSetting.ip_setting.enabled?
  rescue StandardError
    false
  end
end
