class MealSetting < ApplicationRecord
  MEAL_TYPES = %w[morning_tea breakfast lunch evening_tea].freeze

  validates :meal_type, presence: true,
            uniqueness: true,
            inclusion: { in: MEAL_TYPES }

  validates :start_time, :end_time, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }

  def available_now?(time = Time.current)
    return false if start_time.blank? || end_time.blank?

    if end_time < start_time
      time >= start_time || time <= end_time
    else
      time.between?(start_time, end_time)
    end
  end

  def label
    meal_type.to_s.humanize.titleize
  end

  def formatted_start_time
    start_time&.strftime("%H:%M")
  end

  def formatted_end_time
    end_time&.strftime("%H:%M")
  end

  def formatted_time_range
    return unless start_time && end_time
    "#{formatted_start_time} – #{formatted_end_time}"
  end
end