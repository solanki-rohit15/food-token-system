# Public::QRController
#
# Every QR code now encodes a URL: https://host/qr/<signed_token>
# When anyone scans the QR with a phone camera, they land here.
#
# Behaviour by role:
#   • Not logged in / employee / admin  →  public read-only view (HTML)
#   • Authenticated vendor              →  redirect to scanner page with item pre-loaded
#
# Security:
#   - Only an HMAC-SHA256 signed token is in the URL — never a raw item_code or DB id
#   - Token expires in 24 h (configurable via QR_TOKEN_TTL env var)
#   - Tampering with the signed string raises InvalidSignature → 404
class Public::QRController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :enforce_password_change!
  skip_before_action :check_location_access, raise: false

  # GET /qr/:signed_token
  def show
    @order_item = resolve_order_item(params[:signed_token])
    return render_invalid unless @order_item

    if current_user&.vendor?
      # Vendor tapped the QR link — send them to the scanner with the item pre-resolved
      redirect_to vendor_scan_path(item_code: @order_item.item_code), allow_other_host: false
    else
      render_public_page
    end
  end

  private

  # Decode and verify the signed token → return matching OrderItem or nil
  def resolve_order_item(signed_token)
    return nil if signed_token.blank?

    payload = OrderItem.qr_verifier.verify(signed_token, purpose: :qr_scan)
    # payload is a Hash with string keys: { "item_code" => "FI-...", "exp" => 1234567890 }

    return nil if payload["exp"].to_i < Time.current.to_i  # expired

    OrderItem.includes(:food_item, order: [ :user, :token ])
             .find_by(item_code: payload["item_code"])

  rescue ActiveSupport::MessageVerifier::InvalidSignature,
         ActiveSupport::MessageEncryptor::InvalidMessage,
         JSON::ParserError, TypeError, ArgumentError
    # Any tamper attempt or bad token → treat as not found
    nil
  end

  def render_public_page
    order  = @order_item.order
    @data  = {
      category:   @order_item.food_item.category_label,
      icon:       @order_item.food_item.icon,
      date:       order.date.strftime("%d %b %Y"),
      first_name: order.user.name.split.first,
      redeemed:   @order_item.redeemed?,
      redeemed_at: @order_item.redeemed_at&.strftime("%I:%M %p")
    }
    render "public/qr/show", layout: false   # standalone page — no app layout
  end

  def render_invalid
    render "public/qr/invalid", layout: false, status: :not_found
  end
end
