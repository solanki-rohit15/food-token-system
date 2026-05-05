require "rqrcode"

class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :food_item
  belongs_to :redeemed_by, class_name: "User", optional: true, foreign_key: :redeemed_by_id

  has_many :redemption_requests, dependent: :destroy

  before_validation :generate_item_code, on: :create
  after_create      :generate_and_store_signed_qr_token

  validates :item_code, presence: true, uniqueness: true

  # ── QR: signed URL (no sensitive data in QR payload) ──────────────
  #
  # The QR encodes only a full HTTPS URL: https://app.host/qr/<signed_token>
  # The signed_token is an HMAC-SHA256 signed blob containing ONLY:
  #   { item_code: "FI-XXXXXXXX", exp: unix_timestamp }
  # The raw item_code is never visible to the scanner or the QR image consumer.
  # Tampering with the token string invalidates the HMAC signature.
  #
  # Usage:
  #   item.qr_svg   → returns SVG string to embed in the employee token page
  #   item.full_qr_url → the URL encoded in the QR (for debugging / regeneration)

  def full_qr_url
    host   = ENV.fetch("APP_HOST", "localhost:3000")
    scheme = Rails.env.production? ? "https" : "http"
    token  = signed_qr_token.presence || regenerate_signed_qr_token
    "#{scheme}://#{host}/qr/#{ERB::Util.url_encode(token)}"
  end

  def qr_svg
    RQRCode::QRCode.new(full_qr_url).as_svg(
      offset:           0,
      color:            "000",
      shape_rendering:  "crispEdges",
      module_size:      5,
      standalone:       true,
      use_path:         true,
      viewbox:          true
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
  # Uses a DB-level row lock to prevent double-redemption race condition.
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

  # ── Signed QR token management ───────────────────────────────────
  def regenerate_signed_qr_token
    token = self.class.qr_verifier.generate(
      { "item_code" => item_code, "exp" => 24.hours.from_now.to_i },
      purpose: :qr_scan
    )
    update_column(:signed_qr_token, token)
    token
  end

  # Shared verifier — used by model (generate) and controller (verify).
  # Key: secret_key_base   Digest: SHA256   Serializer: JSON (not Marshal, for safety)
  def self.qr_verifier
    @qr_verifier ||= ActiveSupport::MessageVerifier.new(
      Rails.application.secret_key_base,
      digest:     "SHA256",
      serializer: JSON
    )
  end

  private

  def generate_and_store_signed_qr_token
    regenerate_signed_qr_token
  end

  def generate_item_code
    return if item_code.present?
    self.item_code = loop do
      code = "FI-#{SecureRandom.alphanumeric(8).upcase}"
      break code unless self.class.exists?(item_code: code)
    end
  end
end
