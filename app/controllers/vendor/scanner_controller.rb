# Vendor::ScannerController
#
# All responses are JSON — no HTML redirects from #verify.
# Works with:
#   1. New signed URL format  : https://host/qr/<signed_token>   (or bare signed token)
#   2. Legacy item code       : FI-XXXXXXXX  (plain string or inside JSON)
#   3. Legacy token code      : FT-XXXXXXXX  (plain string or inside JSON)
class Vendor::ScannerController < ApplicationController
  before_action :require_vendor!

  # GET /vendor/scan
  def index
    # If the vendor arrived via a redirect from Public::QrController
    # (they tapped the QR URL while logged in as a vendor),
    # pre-resolve the item so the result appears immediately.
    @prefilled_result = resolve_prefilled if params[:item_code].present?
  end

  # POST /vendor/scan/verify
  # Body: { qr_data: "<any supported format>" }
  # Always returns JSON.
  def verify
    qr_data = params[:qr_data].to_s.strip
    return render_error("No QR data provided.") if qr_data.blank?

    order_item = resolve_order_item(qr_data)
    token      = order_item&.token || resolve_token(qr_data)

    return render_error("Token not found.")          unless token
    return render_error("Token has expired.")        if token.expired?
    
    if token.redeemed?
      return render json: {
        valid:         false,
        fully_redeemed: true,
        redeemed_at:   token.redeemed_at&.strftime("%I:%M %p"),
        employee_name: token.user.name,
        items:         [item_data(token.order_item)]
      }
    end

    broadcast_scan_to_employee(token)

    render json: build_verify_payload(token, token.order_item)
  end

  private

  # ── Resolution ────────────────────────────────────────────────────

  def resolve_prefilled
    item = OrderItem.includes(:food_item, :token, order: :user)
                    .find_by(item_code: params[:item_code])
    return nil unless item

    token = item.token
    return nil unless token

    build_verify_payload(token, item)
  end

  def resolve_order_item(data)
    try_signed_url(data) || try_json_item_code(data) || find_item_by_code(data)
  end

  # Handles "https://host/qr/<token>" OR a bare signed token string
  def try_signed_url(data)
    signed_token = extract_signed_token_from(data)
    return nil if signed_token.blank?

    payload = OrderItem.qr_verifier.verify(signed_token, purpose: :qr_scan)
    return nil if payload["exp"].to_i < Time.current.to_i

    find_item_by_code(payload["item_code"])
  rescue ActiveSupport::MessageVerifier::InvalidSignature,
         ActiveSupport::MessageEncryptor::InvalidMessage,
         JSON::ParserError, TypeError, ArgumentError
    nil
  end

  def try_json_item_code(data)
    return nil unless data.start_with?("{")
    parsed = JSON.parse(data)
    find_item_by_code(parsed["item_code"]) if parsed["item_code"].present?
  rescue JSON::ParserError
    nil
  end

  def find_item_by_code(item_code)
    return nil if item_code.blank?
    OrderItem.includes(:food_item, :token, order: :user)
             .find_by(item_code: item_code.to_s.strip)
  end

  def resolve_token(data)
    Token.find_by_qr(data)
  end

  # Extract signed token portion from either a full URL or a bare string
  def extract_signed_token_from(data)
    if data.include?("/qr/")
      URI.decode_www_form_component(data.split("/qr/").last.strip)
    elsif data.length > 40 && !data.start_with?("FT-", "FI-", "{", "http")
      data  # bare signed token
    end
  rescue URI::InvalidURIError
    nil
  end

  # ── Response builders ─────────────────────────────────────────────

  def build_verify_payload(token, scanned_item = nil)
    {
      valid:        true,
      token_id:     token.id,
      token_number: token.token_number,
      expires_at:   token.expires_at.strftime("%I:%M %p"),
      scanned_item: scanned_item_data(scanned_item),
      employee: {
        name:       token.user.name,
        email:      token.user.email,
        initials:   token.user.initials,
        employee_id: token.user.employee_profile&.employee_id
      },
      items: [item_data(token.order_item)]
    }
  end

  def scanned_item_data(oi)
    return nil unless oi
    {
      order_item_id: oi.id,
      item_code:     oi.item_code,
      category:      oi.food_item.category_label
    }
  end

  def item_data(oi)
    {
      order_item_id: oi.id,
      item_code:     oi.item_code,
      category:      oi.food_item.category,
      label:         oi.food_item.category_label,
      icon:          oi.food_item.icon,
      redeemed:      oi.redeemed?,
      redeemed_at:   oi.redeemed_at&.strftime("%I:%M %p")
    }
  end

  # ── ActionCable ───────────────────────────────────────────────────

  def broadcast_scan_to_employee(token)
    ActionCable.server.broadcast("user_#{token.user.id}", {
      event:    "scan_request",
      token_id: token.id,
      vendor:   current_user.name,
      message:  "#{current_user.name} scanned your QR code"
    })
  rescue StandardError => e
    Rails.logger.error("[ScannerController] Cable broadcast failed: #{e.message}")
  end

  # ── Error helper ──────────────────────────────────────────────────

  def render_error(message, extra: {})
    render json: { valid: false, message: message }.merge(extra),
           status: :unprocessable_entity
  end
end
