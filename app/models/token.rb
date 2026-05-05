require "rqrcode"

class Token < ApplicationRecord
  belongs_to :order
  belongs_to :redeemed_by_user, class_name: "User", foreign_key: :redeemed_by_id, optional: true
  has_many   :redemption_requests, dependent: :destroy

  enum :status, { active: 0, redeemed: 1, expired: 2 }

  TOKEN_EXPIRY_HOURS = 6  # tokens expire 6 hours after generation

  before_validation :ensure_token_number, on: :create
  before_validation :ensure_public_token, on: :create
  before_create     :set_expiry
  after_create      :generate_signed_payload!

  validates :token_number, presence: true, uniqueness: true
  validates :public_token, uniqueness: true, allow_nil: true


  scope :today,      -> { joins(:order).where(orders: { date: Date.current }) }
  scope :this_month, -> { joins(:order).where(orders: { date: Date.current.beginning_of_month..Date.current.end_of_month }) }
  scope :for_user,   ->(user) { joins(:order).where(orders: { user_id: user.id }) }
  scope :by_status,  ->(s) { where(status: s) }
  scope :for_date,   ->(date) { joins(:order).where(orders: { date: date }) }
  scope :expired_by_time, -> { where("expires_at < ?", Time.current).where.not(status: statuses[:redeemed]) }
  scope :expired_effective, lambda {
    where(status: statuses[:expired])
      .or(where("expires_at < ? AND status != ?", Time.current, statuses[:redeemed]))
  }

  delegate :user, :food_items, :summary, to: :order


  def expired_by_time? = expires_at.present? && expires_at < Time.current
  def expired?         = status == "expired" || expired_by_time?
  def redeemable?      = active? && !expired_by_time?
  def pending_request? = redemption_requests.pending.exists?
  def fully_redeemed?  = status == "redeemed"

  def redeemed_items_count = order.order_items.count { |oi| oi.redeemed_at.present? }
  def pending_items_count  = order.order_items.count { |oi| oi.redeemed_at.nil? }
  def partially_redeemed?  = active? && redeemed_items_count > 0


  def status_payload
    order_items_data = order.order_items.includes(:food_item).map do |oi|
      {
        item_code:      oi.item_code,
        category:       oi.food_item.category,
        category_label: oi.food_item.category_label,
        redeemed:       oi.redeemed?,
        redeemed_at:    oi.redeemed_at&.strftime("%I:%M %p")
      }
    end

    pending = redemption_requests
                    .pending
                    .includes(:vendor, order_item: :food_item)
                    .map do |req|
      { id: req.id, vendor_name: req.vendor.name,
        category: req.order_item.food_item.category_label,
        item_code: req.order_item.item_code }
    end

    {
      token_status:       status,
      fully_redeemed:     fully_redeemed?,
      partially_redeemed: partially_redeemed?,
      expired:            expired?,
      order_items:        order_items_data,
      pending_requests:   pending
    }
  end


  def self.find_by_qr(data)
    parsed = JSON.parse(data.to_s)
    find_by(token_number: parsed["token"]) || find_by(id: parsed["id"])
  rescue JSON::ParserError
    find_by(token_number: data.strip)
  end

  def redeem!(vendor_user = nil)
    return false if redeemed?
    update!(status: :redeemed, redeemed_at: Time.current, redeemed_by_id: vendor_user&.id)
  end

  def self.expire_stale!
    where(status: :active).where("expires_at < ?", Time.current)
      .update_all(status: statuses[:expired], updated_at: Time.current)
  end

  def self.expiry_time_for(_date = nil)
    Time.current + TOKEN_EXPIRY_HOURS.hours
  end

  private

  def ensure_token_number
    self.token_number ||= loop do
      code = "FT-#{SecureRandom.alphanumeric(8).upcase}"
      break code unless Token.exists?(token_number: code)
    end
  end

  def ensure_public_token
    self.public_token ||= loop do
      pt = QR::Signer.generate_public_token
      break pt unless Token.exists?(public_token: pt)
    end
  end

  def set_expiry
    self.expires_at ||= Time.current + self.class::TOKEN_EXPIRY_HOURS.hours
  end

  # After create: generate and store the signed payload
  def generate_signed_payload!
    payload = {
      type:         "token",
      record_id:    id,
      public_token: public_token,
      token_number: token_number,
      issued_at:    Time.current.to_i
    }
    update_column(:signed_payload, QR::Signer.sign(payload))
  end
end
