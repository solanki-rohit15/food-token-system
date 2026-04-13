class MealSetting < ApplicationRecord
  MEAL_TYPES = %w[morning_tea breakfast lunch evening_tea].freeze

  validates :meal_type, presence: true,
            uniqueness: true,
            inclusion: { in: MEAL_TYPES }

  validates :start_time, :end_time, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }

  # ── Defaults ─────────────────────────────
  def self.defaults
    {
      "morning_tea" => { start_time: "08:00", end_time: "11:00", price: 20 },
      "breakfast"   => { start_time: "08:30", end_time: "11:00", price: 30 },
      "lunch"       => { start_time: "12:00", end_time: "14:30", price: 120 },
      "evening_tea" => { start_time: "15:30", end_time: "18:00", price: 20 }
    }
  end

  # ── Safe initializer ─────────────────────
  def self.find_or_initialize_for(meal_type)
    find_or_initialize_by(meal_type: meal_type).tap do |s|
      next unless s.new_record?

      d = defaults[meal_type.to_s] || {}

      s.start_time = parse_time(d[:start_time]) || Time.zone.parse("09:00")
      s.end_time   = parse_time(d[:end_time])   || Time.zone.parse("17:00")
      s.price      = d[:price] || 0
    end
  end

  # ── Time parser ──────────────────────────
  def self.parse_time(str)
    return nil if str.blank?
    Time.zone.parse(str)
  end

  # ── Availability check ───────────────────
  def available_now?(time = Time.current)
    return false if start_time.blank? || end_time.blank?

    start_t = start_time
    end_t   = end_time

    if end_t < start_t
      time >= start_t || time <= end_t  # crosses midnight
    else
      time.between?(start_t, end_t)
    end
  end

  # ── Helpers ──────────────────────────────
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