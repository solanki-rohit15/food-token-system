class Admin::MealSettingsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!

  def index
    @settings = MealSetting.order(:meal_type)
  end

  def update
    settings_to_save = build_settings_from_params
    errors           = collect_validation_errors(settings_to_save)

    if errors.empty?
      ActiveRecord::Base.transaction do
        settings_to_save.each(&:save!)
      end
      render json: {
        success: true,
        message: "Meal settings updated.",
        settings: settings_to_save.map do |setting|
          {
            meal_type: setting.meal_type,
            start_time: setting.start_time&.strftime("%H:%M"),
            end_time: setting.end_time&.strftime("%H:%M"),
            price: setting.price.to_f
          }
        end
      }
    else
      render json: { success: false, message: errors.to_sentence }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordInvalid => e
    render json: { success: false, message: e.message }, status: :unprocessable_entity
  end

  private

  def build_settings_from_params
    meal_settings_params.to_h.filter_map do |mt, attrs|
      next unless MealSetting::MEAL_TYPES.include?(mt)
  
      setting = MealSetting.find_by!(meal_type: mt)
  
      setting.start_time = parse_time(attrs[:start_time]) || setting.start_time
      setting.end_time   = parse_time(attrs[:end_time])   || setting.end_time
      setting.price      = attrs[:price].to_f
  
      setting
    end
  end
  
  def meal_settings_params
    params.require(:meal_settings).permit!
  end

  def collect_validation_errors(settings)
    settings.reject(&:valid?).flat_map do |s|
      s.errors.full_messages.map { |msg| "#{s.meal_type.humanize}: #{msg}" }
    end
  end

  def parse_time(value)
    return nil if value.blank?
    Time.zone.parse(value)
  rescue ArgumentError
    nil
  end
end