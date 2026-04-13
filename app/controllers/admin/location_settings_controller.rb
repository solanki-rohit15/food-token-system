class Admin::LocationSettingsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin!

  def index
    @setting = LocationSetting.gps_setting
  end

  def update
    @setting = LocationSetting.gps_setting
    attrs = params.require(:location_setting)
                  .permit(:name, :enabled, :latitude, :longitude, :radius_meters)

    # Checkbox sends "1"/"0" — coerce to boolean
    attrs[:enabled] = attrs[:enabled].to_s == "1"

    if @setting.update(attrs)
      redirect_to admin_location_settings_path, notice: "Location settings saved."
    else
      flash.now[:alert] = @setting.errors.full_messages.join(", ")
      render :index, status: :unprocessable_entity
    end
  end

  private

  def ensure_admin!
    redirect_to root_path unless current_user.admin?
  end
end
