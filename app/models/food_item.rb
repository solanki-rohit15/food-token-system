class FoodItem < ApplicationRecord
  CATEGORIES = {
    "morning_tea" => { label: "Morning Tea",  icon: "☕", color: "warning", cutoff_hour: 11 },
    "breakfast"   => { label: "Breakfast",    icon: "🥐", color: "success", cutoff_hour: 11 },
    "lunch"       => { label: "Lunch",        icon: "🍱", color: "primary", cutoff_hour: 14 },
    "evening_tea" => { label: "Evening Tea",  icon: "🫖", color: "info",    cutoff_hour: 18 }
  }.freeze

  has_many :order_items, dependent: :destroy
  has_many :orders, through: :order_items

  validates :category, presence: true,
                       inclusion: { in: CATEGORIES.keys },
                       uniqueness: true

  scope :active,   -> { where(active: true) }
  scope :ordered,  -> { order(:sort_order, :category) }
  scope :for_category, ->(cat) { where(category: cat.to_s) }

  # ⚠️ Avoid using Ruby select in scopes for large data
  scope :available_now, -> { active } # filter later if needed

  # ✅ FINAL LOGIC (correct + safe)
  def available_now?(time = Time.current)
    return false unless active?

    setting = MealSetting.find_by(meal_type: category)

    # 👉 fallback if no setting
    return default_available?(time) unless setting&.start_time && setting&.end_time

    now = time.in_time_zone

    now_sec   = now.seconds_since_midnight
    start_sec = setting.start_time.seconds_since_midnight
    end_sec   = setting.end_time.seconds_since_midnight

    if start_sec <= end_sec
      now_sec.between?(start_sec, end_sec)
    else
      # ✅ Cross-midnight support (rare but safe)
      now_sec >= start_sec || now_sec <= end_sec
    end
  end

  def category_info
    CATEGORIES[category.to_s] || {}
  end

  def icon
    category_info[:icon] || "🍽️"
  end

  def color
    category_info[:color] || "secondary"
  end

  def category_label
    category_info[:label] || category.to_s.humanize
  end

  # ✅ Optimized (avoid multiple DB hits)
  def meal_setting
    @meal_setting ||= MealSetting.find_by(meal_type: category)
  end

  def price
    meal_setting&.price.to_f
  end

  private

  def default_available?(time)
    hour   = time.hour
    cutoff = CATEGORIES.dig(category.to_s, :cutoff_hour) || 18
    hour < cutoff
  end
end