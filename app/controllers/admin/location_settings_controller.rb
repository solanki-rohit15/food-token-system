class Admin::LocationSettingsController < ApplicationController
  before_action :require_admin!
  before_action :load_setting

  def index; end

  def update
    # Permit the attributes
    attrs = params.require(:location_setting)
                  .permit(:name, :enabled, :latitude, :longitude, :radius_meters)

    # Checkbox sends "1"/"0" — coerce to boolean
    attrs[:enabled] = attrs[:enabled].to_s == "1"

    if @setting.update(attrs)
      render json: {
        success: true,
        message: "Location settings saved.",
        setting: {
          enabled: @setting.enabled?,
          name: @setting.name,
          latitude: @setting.latitude,
          longitude: @setting.longitude,
          radius_meters: @setting.radius_meters
        }
      }
    else
      error_message = @setting.errors.full_messages.join(", ")
      render json: { success: false, message: error_message }, status: :unprocessable_entity
    end
  end

  private

  # Load the GPS setting
  def load_setting
    @setting = LocationSetting.gps_setting
  end
end
