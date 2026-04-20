require "rqrcode"

class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :food_item
  belongs_to :redeemed_by, class_name: "User", optional: true, foreign_key: :redeemed_by_id

  has_many :redemption_requests, dependent: :destroy

  before_validation :generate_item_code, on: :create

  validates :item_code, presence: true, uniqueness: true

  # ── QR (per-item — encodes item_code + category) ──────────────────
  def qr_payload
    {
      item_code: item_code,
      category:  food_item.category,
      token:     order.token&.token_number
    }.to_json
  end

  def qr_svg
    qr = RQRCode::QRCode.new(qr_payload)
    qr.as_svg(
      offset: 0, color: "000",
      shape_rendering: "crispEdges",
      module_size: 5, standalone: true, use_path: true
    )
  end

  # ── Status ────────────────────────────────────────────────────────
  def redeemed?
    redeemed_at.present?
  end

  def pending_redemption_request?
    redemption_requests.pending.exists?
  end

  # ── Redeem ────────────────────────────────────────────────────────
  # Uses a DB-level lock to prevent race conditions when two vendors
  # try to redeem the same item simultaneously.
  def redeem!(vendor_user)
    with_lock do
      return false if redeemed?
      update!(
        redeemed_at:    Time.current,
        redeemed_by_id: vendor_user&.id
      )
    end
    true
  end

  private

  def generate_item_code
    return if item_code.present?
    self.item_code = loop do
      code = "FI-#{SecureRandom.alphanumeric(8).upcase}"
      break code unless self.class.exists?(item_code: code)
    end
  end
end
