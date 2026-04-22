class Vendor::TokensController < ApplicationController
  before_action :authenticate_user!
  before_action :require_vendor!
  before_action :set_token, only: [:show, :send_redemption_request]

  def index
    @date   = safe_parse_date(params[:date]) || Date.current
    @tokens = Token.for_date(@date)
                   .includes(order: [:user, :food_items])
                   .order(created_at: :desc)
                   .page(params[:page]).per(20)
  end

  def show
    @order           = @token.order
    @employee        = @order.user
    @order_items     = @order.order_items.includes(:food_item, :redemption_requests)
    @food_items      = @order.food_items
    @pending_requests = @token.redemption_requests.pending.includes(:order_item)
  end

  # POST /vendor/tokens/:id/send_redemption_request?order_item_id=X
  def send_redemption_request
    order_item = @token.order.order_items
                       .includes(:food_item)
                       .find_by(id: params[:order_item_id])

    unless order_item
      return render json: { success: false, message: "Item not found for this token." },
                    status: :not_found
    end

    if order_item.redeemed?
      return render json: { success: false, message: "#{order_item.food_item.category_label} has already been redeemed." },
                    status: :unprocessable_entity
    end

    unless @token.redeemable?
      return render json: { success: false, message: "Token is not redeemable (#{@token.status})." },
                    status: :unprocessable_entity
    end

    if RedemptionRequest.exists?(order_item_id: order_item.id, status: :pending)
      return render json: { success: false, message: "A request is already pending for #{order_item.food_item.category_label}." },
                    status: :unprocessable_entity
    end

    req = RedemptionRequest.create!(
      token:      @token,
      order_item: order_item,
      vendor:     current_user,
      status:     :pending
    )

    # Real-time push to employee
    ActionCable.server.broadcast("user_#{@token.user.id}", {
      event:                "redemption_request",
      redemption_request_id: req.id,
      token_id:             @token.id,
      item_code:            order_item.item_code,
      category:             order_item.food_item.category_label,
      vendor_name:          current_user.name,
      vendor_stall:         current_user.vendor_profile&.stall_name,
      message:              "#{current_user.name} wants to redeem #{order_item.food_item.category_label}"
    })

    render json: { success: true, message: "Request sent. Waiting for employee approval." }

  rescue ActiveRecord::RecordInvalid => e
    render json: { success: false, message: e.message }, status: :unprocessable_entity
  end

  private

  def set_token
    @token = Token.includes(order: [:user, :food_items, :order_items]).find_by(id: params[:id])
    redirect_to vendor_tokens_path, alert: "Token not found." unless @token
  end

end
