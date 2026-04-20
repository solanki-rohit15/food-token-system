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

    ActiveRecord::Base.transaction do
      (params[:meal_settings] || {}).each do |mt, attrs|
        next unless MealSetting::MEAL_TYPES.include?(mt)

        setting = MealSetting.find_or_initialize_for(mt)

        # ✅ SAFE TIME PARSING (IMPORTANT)
        start_time = parse_time(attrs[:start_time])
        end_time   = parse_time(attrs[:end_time])

        setting.start_time = start_time if start_time
        setting.end_time   = end_time   if end_time
        setting.price      = attrs[:price].to_f

        unless setting.save
          errors << "#{mt.humanize}: #{setting.errors.full_messages.join(', ')}"
        end
      end

      # ❗ Rollback manually if any errors
      raise ActiveRecord::Rollback if errors.any?
    end

    if errors.empty?
      redirect_to admin_meal_settings_path, notice: "Meal settings updated successfully ✅"
    else
      @settings = MealSetting::MEAL_TYPES.map do |mt|
        MealSetting.find_or_initialize_for(mt)
      end

      flash.now[:alert] = errors.join("; ")
      render :index, status: :unprocessable_entity
    end
  end

  private

  # ✅ CENTRALIZED TIME PARSER
  def parse_time(value)
    return nil if value.blank?

    # Ensures correct timezone + avoids invalid formats
    Time.zone.parse(value)
  rescue ArgumentError
    nil
  end

  def ensure_admin!
    redirect_to root_path, alert: "Access denied." unless current_user.admin?
  end
end