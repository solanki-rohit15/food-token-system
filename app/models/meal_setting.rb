class MealSetting < ApplicationRecord
  validates :meal_type, presence: true, uniqueness: true
  validates :start_time, :end_time, presence: true

  MEAL_TYPES = %w[morning_tea breakfast lunch evening_tea].freeze
  validates :meal_type, inclusion: { in: MEAL_TYPES }

  def self.defaults
    {
      "morning_tea" => { start_time: "08:00", end_time: "11:00" },
      "breakfast"   => { start_time: "08:30", end_time: "11:00" },
      "lunch"       => { start_time: "12:00", end_time: "14:30" },
      "evening_tea" => { start_time: "15:30", end_time: "18:00" }
    }
  end

  def self.find_or_initialize_for(meal_type)
    find_or_initialize_by(meal_type: meal_type).tap do |setting|
      if setting.new_record?
        defaults_for = defaults[meal_type.to_s] || {}
        setting.start_time = defaults_for[:start_time] || "09:00"
        setting.end_time   = defaults_for[:end_time]   || "17:00"
      end
    end
  end

  def available_now?(time = Time.current)
    current = time.strftime("%H:%M")
    current >= start_time && current <= end_time
  end

  def label
    meal_type.humanize.titleize
  end
end
