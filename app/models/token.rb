require "rqrcode"

class Token < ApplicationRecord
  belongs_to :order

  enum :status, { active: 0, redeemed: 1, expired: 2 }

  TOKEN_VALID_FROM  = "10:00"
  TOKEN_VALID_UNTIL = "18:00"

  before_create :ensure_qr_code
  before_create :set_expiry

  scope :today,      -> { joins(:order).where(orders: { date: Date.current }) }
  scope :this_month, -> { joins(:order).where(orders: { date: Date.current.beginning_of_month..Date.current.end_of_month }) }
  scope :for_user,   ->(user) { joins(:order).where(orders: { user_id: user.id }) }
  scope :by_status,  ->(s) { where(status: s) }
  scope :for_date,   ->(date) { joins(:order).where(orders: { date: date }) }

  delegate :user,       to: :order
  delegate :food_items, to: :order
  delegate :summary,    to: :order

  def qr_svg
    qr = RQRCode::QRCode.new(qr_payload)
    qr.as_svg(
      offset:          0,
      color:           "000",
      shape_rendering: "crispEdges",
      module_size:     4,
      standalone:      true,
      use_path:        true
    )
  end

  def qr_payload
    { token_id: id, code: qr_code, expires: expires_at.to_i }.to_json
  end

  def expired_by_time?
    expires_at < Time.current
  end

  def expired?
    status == "expired" || expired_by_time?
  end

  def redeemable?
    active? && !expired_by_time?
  end

  def self.verify(code)
    token = find_by(qr_code: code)
    return { valid: false, message: "Token not found" } unless token
    return { valid: false, message: "Token already redeemed", token: token } if token.redeemed?
    return { valid: false, message: "Token has expired", token: token }     if token.expired?

    { valid: true, token: token, message: "Token is valid" }
  end

  def redeem!(vendor_user = nil)
    return false unless redeemable?

    update!(
      status:      :redeemed,
      redeemed_at: Time.current,
      redeemed_by: vendor_user&.id
    )
  end

  private

  def ensure_qr_code
    self.qr_code ||= SecureRandom.urlsafe_base64(32)
  end

  def set_expiry
    today = Date.current
    self.expires_at ||= Time.zone.parse("#{today} #{TOKEN_VALID_UNTIL}")
  end
end
