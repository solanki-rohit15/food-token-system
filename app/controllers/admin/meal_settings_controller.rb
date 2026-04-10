class Admin::MealSettingsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin!

  def index
    @settings = MealSetting::MEAL_TYPES.map do |mt|
      MealSetting.find_or_initialize_for(mt)
    end
  end

  def update
    errors = []

    MealSetting::MEAL_TYPES.each do |mt|
      next unless params[:meal_settings]&.key?(mt)

      setting = MealSetting.find_or_initialize_by(meal_type: mt)
      attrs   = params[:meal_settings][mt].permit(:start_time, :end_time)

      unless setting.update(attrs)
        errors << "#{mt.humanize}: #{setting.errors.full_messages.join(', ')}"
      end
    end

    if errors.empty?
      redirect_to admin_meal_settings_path, notice: "Meal timings updated."
    else
      redirect_to admin_meal_settings_path, alert: errors.join("; ")
    end
  end

  private

  def ensure_admin!
    redirect_to root_path unless current_user.admin?
  end
end
