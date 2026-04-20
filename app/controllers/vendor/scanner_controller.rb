class Vendor::ScannerController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_vendor!

  def index; end

  def verify
    qr_data = params[:qr_data].to_s.strip
    return render_json_error("No QR data provided.") if qr_data.blank?

    # Try per-item QR first, then token-level QR
    order_item = resolve_order_item(qr_data)
    token      = order_item&.order&.token || resolve_token(qr_data)

    return render_json_error("Token not found.")                                       if token.nil?
    return render_json_error("Token has expired.")                                     if token.expired?
    return render_json_error("Token has been fully redeemed.",
                             redeemed_at: token.redeemed_at&.strftime("%I:%M %p"))    if token.fully_redeemed?

    # Notify employee via ActionCable
    ActionCable.server.broadcast("user_#{token.user.id}", {
      event:    "scan_request",
      token_id: token.id,
      vendor:   current_user.name,
      message:  "#{current_user.name} scanned your QR code"
    })

    # Build per-item data including order_item_id so scanner JS can call
    # send_redemption_request with the right item
    items_data = token.order.order_items.includes(:food_item).map do |oi|
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

    render json: {
      valid:        true,
      token_id:     token.id,
      token_number: token.token_number,
      scanned_item: order_item ? {
        item_code: order_item.item_code,
        category:  order_item.food_item.category_label
      } : nil,
      employee: {
        name:       token.user.name,
        email:      token.user.email,
        initials:   token.user.initials,
        department: token.user.employee_profile&.department
      },
      items:      items_data,
      expires_at: token.expires_at.strftime("%I:%M %p")
    }
  end

  private

  def resolve_order_item(data)
    parsed = JSON.parse(data)
    item_code = parsed["item_code"]
    return nil unless item_code.present?

    OrderItem.joins(order: :token)
             .includes(order: [:token, :food_items])
             .find_by(item_code: item_code)
  rescue JSON::ParserError
    # Plain FI-XXXXXXXX string
    OrderItem.joins(order: :token)
             .includes(order: [:token, :food_items])
             .find_by(item_code: data.strip)
  end

  def resolve_token(data)
    Token.find_by_qr(data)
  end

  def render_json_error(message, extra = {})
    render json: { valid: false, message: message }.merge(extra),
           status: :unprocessable_entity
  end

  def ensure_vendor!
    redirect_to root_path, alert: "Access denied." unless current_user.vendor?
  end
end
