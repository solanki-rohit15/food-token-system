class Admin::LocationSettingsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin!

  def index
    @ip_setting  = LocationSetting.ip_setting
    @gps_setting = LocationSetting.gps_setting
  end

  def update
    ip_attrs  = params.dig(:location_settings, :ip_based)&.permit(:enabled, :ip_range)
    gps_attrs = params.dig(:location_settings, :gps_based)&.permit(:enabled, :latitude, :longitude, :radius_meters)

    ip_ok  = ip_attrs.blank?  || LocationSetting.ip_setting.update(ip_attrs)
    gps_ok = gps_attrs.blank? || LocationSetting.gps_setting.update(gps_attrs)

    if ip_ok && gps_ok
      redirect_to admin_location_settings_path, notice: "Location settings updated."
    else
      redirect_to admin_location_settings_path, alert: "Could not update location settings."
    end
  end

  private

  def ensure_admin!
    redirect_to root_path unless current_user.admin?
  end
end
