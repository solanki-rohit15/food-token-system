class Order < ApplicationRecord
  belongs_to :user
  has_many   :order_items, dependent: :destroy
  has_many   :food_items, through: :order_items
  has_one    :token, dependent: :destroy

  scope :today,      -> { where(date: Date.current) }
  scope :for_date,   ->(date) { where(date: date) }
  scope :this_month, -> { where(date: Date.current.beginning_of_month..Date.current.end_of_month) }

  validates :date,    presence: true
  validates :user_id, uniqueness: { scope: :date, message: "already has an order for today" }

  before_validation :set_date

  def generate_token!
    return token if token.present?
    create_token!(
      qr_code:    SecureRandom.urlsafe_base64(32),
      expires_at: token_expiry_time,
      status:     :active
    )
  end

  def total_items
    order_items.count
  end

  def summary
    food_items.map { |fi| "#{fi.icon} #{fi.name}" }.join(", ")
  end

  private

  def set_date
    self.date ||= Date.current
  end

  def token_expiry_time
    today = Date.current
    Time.zone.parse("#{today} #{Token::TOKEN_VALID_UNTIL}")
  end
end
