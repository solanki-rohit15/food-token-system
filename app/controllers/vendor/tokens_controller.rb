class Vendor::TokensController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_vendor!
  before_action :set_token, only: [:show, :send_redemption_request]

  # ✅ SHOW
  def show
    @order    = @token.order
    @employee = @order.user
    @order_items = @order.order_items.includes(:food_item)
    @food_items = @order.food_items

    # pending requests per item
    @pending_requests = @token.redemption_requests.pending.includes(:order_item)
  end

  # ✅ INDEX
  def index
    @date = params[:date].present? ? Date.parse(params[:date]) : Date.current
    @tokens = Token.for_date(@date).page(params[:page])
  end

  # ✅ SEND REQUEST (PER CATEGORY)
  def send_redemption_request
  order_item = OrderItem.find(params[:order_item_id])

  unless @token.redeemable?
    return render json: { success: false, message: "Token not redeemable" }, status: :unprocessable_entity
  end

  if RedemptionRequest.exists?(order_item: order_item, status: :pending)
    return render json: { success: false, message: "Already requested for this item" }, status: :unprocessable_entity
  end

  req = RedemptionRequest.create!(
    token: @token,
    order_item: order_item,   # ✅ KEY FIX
    vendor: current_user,
    status: :pending
  )

  ActionCable.server.broadcast("user_#{@token.user.id}", {
    event: "redemption_request",
    message: "#{current_user.name} wants to redeem #{order_item.food_item.category_label}"
  })

  render json: { success: true }
end

  private

  def set_token
    @token = Token.find(params[:id])
  end

  def ensure_vendor!
    redirect_to root_path unless current_user.vendor?
  end
end