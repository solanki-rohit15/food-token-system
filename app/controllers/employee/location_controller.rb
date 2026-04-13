# Receives GPS coordinates from the browser and stores them in the session.
# The check_location_access before_action then uses these to validate access.
class Employee::LocationController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_employee!

  # POST /employee/location
  # Body: { latitude: float, longitude: float, accuracy: float }
  def update
    lat      = params[:latitude].presence
    lng      = params[:longitude].presence
    accuracy = params[:accuracy].presence

    if lat && lng
      session[:user_lat]      = lat.to_f.round(6)
      session[:user_lng]      = lng.to_f.round(6)
      session[:user_accuracy] = accuracy.to_f.round(1) if accuracy
      session[:location_at]   = Time.current.to_i

      result = LocationSetting.check(lat, lng)

      render json: {
        success:  true,
        status:   result,             # :allowed / :denied / :no_location
        allowed:  result == :allowed,
        distance: compute_distance(lat, lng),
        message:  location_message(result)
      }
    else
      # Browser denied permission — record that in session
      session[:user_lat]    = nil
      session[:user_lng]    = nil
      session[:location_at] = Time.current.to_i

      setting = LocationSetting.gps_setting
      allowed = !setting.enabled?   # if restriction is off, still allowed

      render json: {
        success:  true,
        status:   :no_location,
        allowed:  allowed,
        message:  allowed ? "Location access optional." :
                            "Location permission is required to use this system."
      }
    end
  end

  private

  def compute_distance(lat, lng)
    setting = LocationSetting.gps_setting
    return nil unless setting.latitude && setting.longitude

    LocationSetting.haversine_distance(
      setting.latitude.to_f, setting.longitude.to_f,
      lat.to_f, lng.to_f
    ).round(1)
  end

  def location_message(result)
    case result
    when :allowed      then "Location verified. Access granted."
    when :denied       then "You appear to be outside the office zone."
    when :no_location  then "Could not determine your location."
    end
  end

  def ensure_employee!
    redirect_to root_path unless current_user.employee?
  end
end
