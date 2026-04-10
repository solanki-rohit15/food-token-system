class Vendor::ScannerController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_vendor!

  def index
    # QR scanner page
  end

  def verify
    qr_data = params[:qr_data].to_s.strip

    token = resolve_token(qr_data)

    if token.nil?
      render json: { valid: false, message: "Token not found." }, status: :not_found and return
    end

    if token.redeemed?
      render json: {
        valid:       false,
        message:     "This token has already been redeemed.",
        redeemed_at: token.redeemed_at&.strftime("%I:%M %p")
      }, status: :unprocessable_entity and return
    end

    if token.expired?
      render json: { valid: false, message: "This token has expired." },
        status: :unprocessable_entity and return
    end

    # Notify employee via ActionCable
    ActionCable.server.broadcast("user_#{token.user.id}", {
      event:    "scan_request",
      token_id: token.id,
      vendor:   current_user.name,
      message:  "#{current_user.name} is requesting to redeem your token"
    })

    render json: {
      valid:    true,
      token_id: token.id,
      employee: {
        name:       token.user.name,
        email:      token.user.email,
        initials:   token.user.initials,
        department: token.user.employee_profile&.department
      },
      items:      token.food_items.map { |fi| { name: fi.name, icon: fi.icon, category: fi.category_label } },
      expires_at: token.expires_at.strftime("%I:%M %p")
    }
  end

  private

  def resolve_token(data)
    parsed = JSON.parse(data)
    Token.find_by(id: parsed["token_id"], qr_code: parsed["code"])
  rescue JSON::ParserError
    Token.find_by(qr_code: data)
  end

  def ensure_vendor!
    redirect_to root_path, alert: "Access denied." unless current_user.vendor?
  end
end
