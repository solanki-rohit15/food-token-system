class Order < ApplicationRecord
  belongs_to :user
  has_many   :order_items, dependent: :destroy
  has_many   :food_items,  through: :order_items
  has_one    :token,       dependent: :destroy

  scope :today,      -> { where(date: Date.current) }
  scope :for_date,   ->(date) { where(date: date) }
  scope :this_month, -> { where(date: Date.current.beginning_of_month..Date.current.end_of_month) }

  validates :date,    presence: true

  before_validation :set_date

  def generate_token!
    return token if token.present?
    create_token!(expires_at: token_expiry_time, status: :active)
  end

  def total_items = order_items.count

  # Human-readable list of food items: "☕ Morning Tea, 🍱 Lunch"
  # Pass separator: " · " for the bullet-separated style used in some views.
  def items_label(separator: ", ")
    food_items.map { |fi| "#{fi.icon} #{fi.category_label}" }.join(separator)
  end

  # Alias kept for backward compat (Token delegates `summary` to order)
  alias_method :summary, :items_label

  private

  def set_date
    self.date ||= Date.current
  end

  def token_expiry_time
    Token.expiry_time_for(Date.current)
  end
end
