class FoodItem < ApplicationRecord
  CATEGORIES = {
    "morning_tea" => { label: "Morning Tea",  icon: "☕", color: "warning",  cutoff_hour: 11 },
    "breakfast"   => { label: "Breakfast",    icon: "🥐", color: "success",  cutoff_hour: 11 },
    "lunch"       => { label: "Lunch",        icon: "🍱", color: "primary",  cutoff_hour: 14 },
    "evening_tea" => { label: "Evening Tea",  icon: "🫖", color: "info",     cutoff_hour: 18 }
  }.freeze

  has_many :order_items, dependent: :destroy
  has_many :orders, through: :order_items

  validates :category, presence: true, inclusion: { in: CATEGORIES.keys }

  scope :active,        -> { where(active: true) }
  scope :for_category,  ->(cat) { where(category: cat.to_s) }
  scope :ordered,       -> { order(:sort_order, :category) }
  # scope :available_now, -> { active.select(&:available_now?) }
  

  def available_now?(time = Time.current)
    return false unless active?

    setting = MealSetting.find_by(meal_type: category)
    return default_available?(time) unless setting

    current_time = time.strftime("%H:%M")
    current_time >= setting.start_time && current_time <= setting.end_time
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

  private

  def default_available?(time)
    hour   = time.hour
    cutoff = CATEGORIES.dig(category.to_s, :cutoff_hour) || 18
    hour < cutoff
  end
end
