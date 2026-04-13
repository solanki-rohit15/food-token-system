class ApplicationController < ActionController::Base
  include Pundit::Authorization

  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :enforce_password_change!

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up,        keys: [:name, :role, :phone])
    devise_parameter_sanitizer.permit(:account_update, keys: [:name, :phone, :avatar_url])
  end

  def after_sign_in_path_for(resource)
    resource.must_change_password? ? users_change_password_path : resource.dashboard_path
  end

  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_back(fallback_location: root_path)
  end

  # ── GPS location check (reads lat/lng stored in session by JS) ────
  #
  # Call as `before_action :check_location_access` in controllers
  # that need location verification (employee actions).
  def check_location_access
    setting = LocationSetting.gps_setting
    return unless setting.enabled?

    lat = session[:user_lat]
    lng = session[:user_lng]

    result = LocationSetting.check(lat, lng)
    return if result == :allowed

    # Location stale (older than 30 min) — ask browser to re-send
    if session[:location_at].blank? ||
       Time.current.to_i - session[:location_at].to_i > 30.minutes.to_i
      return  # JS will re-request on next page load
    end

    msg = case result
          when :denied      then "Access denied: you must be within the office zone."
          when :no_location then "Please allow location access to use this feature."
          end

    respond_to do |format|
      format.html { redirect_to employee_root_path, alert: msg }
      format.json { render json: { error: msg, location_required: true }, status: :forbidden }
    end
  end

  def current_time_str
    Time.current.strftime("%H:%M")
  end
  helper_method :current_time_str

  private

  def enforce_password_change!
    return unless user_signed_in?
    return unless current_user.must_change_password?
    return if controller_path.start_with?("users/change_passwords")
    return if devise_controller?

    redirect_to users_change_password_path,
                alert: "Please set a new password before continuing."
  end
end
