class Vendor::ScannerController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_vendor!

  def index; end

  def verify
    qr_data = params[:qr_data].to_s.strip

    # Try item-level QR first, then token-level
    item   = resolve_order_item(qr_data)
    token  = item&.order&.token || resolve_token(qr_data)

    return render_json_error("Token not found.")                     if token.nil?
    return render_json_error("Token has already been redeemed.",
                             redeemed_at: token.redeemed_at&.strftime("%I:%M %p")) if token.redeemed?
    return render_json_error("Token has expired.")                   if token.expired?

    # Broadcast scan notification to employee via ActionCable
    ActionCable.server.broadcast("user_#{token.user.id}", {
      event:    "scan_request",
      token_id: token.id,
      vendor:   current_user.name,
      message:  "#{current_user.name} is requesting to redeem your token"
    })

    render json: {
      valid:        true,
      token_id:     token.id,
      token_number: token.token_number,
      scanned_item: item ? { item_code: item.item_code, category: item.food_item.category_label } : nil,
      employee: {
        name:       token.user.name,
        email:      token.user.email,
        initials:   token.user.initials,
        department: token.user.employee_profile&.department
      },
      items:      token.food_items.map { |fi|
        { icon: fi.icon, label: fi.category_label, category: fi.category }
      },
      expires_at: token.expires_at.strftime("%I:%M %p")
    }
  end

  private

  def resolve_order_item(data)
    parsed = JSON.parse(data)
    return nil unless parsed["item"]
    OrderItem.joins(:order)
             .includes(order: [:token, :food_items])
             .find_by(item_code: parsed["item"])
  rescue JSON::ParserError
    OrderItem.joins(:order).includes(order: [:token, :food_items])
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
