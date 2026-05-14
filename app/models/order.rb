class Order < ApplicationRecord
  belongs_to :user
  has_many   :order_items, dependent: :destroy
  has_many   :food_items,  through: :order_items
  has_many   :tokens,      through: :order_items, dependent: :destroy

  scope :today,      -> { where(date: Date.current) }
  scope :for_date,   ->(date) { where(date: date) }
  scope :this_month, -> { where(date: Date.current.beginning_of_month..Date.current.end_of_month) }

  validates :date,    presence: true

  before_validation :set_date

  def total_items = order_items.count

  # Human-readable list of food items: "☕ Morning Tea, 🍱 Lunch"
  # Pass separator: " · " for the bullet-separated style used in some views.
  def items_label(separator: ", ")
    food_items.map { |fi| "#{fi.icon} #{fi.category_label}" }.join(separator)
  end

  private

  def set_date
    self.date ||= Date.current
  end

end
