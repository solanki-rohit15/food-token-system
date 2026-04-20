require "rqrcode"

class Token < ApplicationRecord
  belongs_to :order
  has_many   :redemption_requests, dependent: :destroy

  enum :status, { active: 0, redeemed: 1, expired: 2 }

  TOKEN_VALID_UNTIL = "18:00"

  before_validation :ensure_token_number, on: :create
  before_create     :set_expiry

  validates :token_number, presence: true, uniqueness: true

  # ── Scopes ─────────────────────────────────────────────────────────
  scope :today,      -> { joins(:order).where(orders: { date: Date.current }) }
  scope :this_month, -> { joins(:order).where(orders: { date: Date.current.beginning_of_month..Date.current.end_of_month }) }
  scope :for_user,   ->(user) { joins(:order).where(orders: { user_id: user.id }) }
  scope :by_status,  ->(s) { where(status: s) }
  scope :for_date,   ->(date) { joins(:order).where(orders: { date: date }) }

  delegate :user, :food_items, :summary, to: :order

  # ── QR ──────────────────────────────────────────────────────────────
  def qr_svg
    RQRCode::QRCode.new(qr_payload).as_svg(
      offset: 0, color: "000", shape_rendering: "crispEdges",
      module_size: 6, standalone: true, use_path: true
    )
  end

  def qr_payload
    { token: token_number, id: id, exp: expires_at.to_i }.to_json
  end

  # ── Status ──────────────────────────────────────────────────────────
  def expired_by_time? = expires_at.present? && expires_at < Time.current
  def expired?         = status == "expired" || expired_by_time?
  def redeemable?      = active? && !expired_by_time?
  def pending_request? = redemption_requests.pending.exists?
  def fully_redeemed?  = status == "redeemed"

  # SQL-based counts — no Ruby iteration over all items
  def redeemed_items_count  = order.order_items.where.not(redeemed_at: nil).count
  def pending_items_count   = order.order_items.where(redeemed_at: nil).count
  def partially_redeemed?   = active? && redeemed_items_count > 0

  # ── QR lookup ───────────────────────────────────────────────────────
  def self.find_by_qr(data)
    parsed = JSON.parse(data.to_s)
    find_by(token_number: parsed["token"]) || find_by(id: parsed["id"])
  rescue JSON::ParserError
    find_by(token_number: data.strip)
  end

  # Called only by RedemptionRequest after all items finalized
  def redeem!(vendor_user = nil)
    return false if redeemed?
    update!(status: :redeemed, redeemed_at: Time.current, redeemed_by: vendor_user&.id)
  end

  private

  def ensure_token_number
    self.token_number ||= loop do
      code = "FT-#{SecureRandom.alphanumeric(8).upcase}"
      break code unless Token.exists?(token_number: code)
    end
  end

  def set_expiry
    self.expires_at ||= Time.zone.parse("#{Date.current} #{TOKEN_VALID_UNTIL}")
  end
end
