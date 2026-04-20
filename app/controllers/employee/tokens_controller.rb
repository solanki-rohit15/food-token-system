class Employee::TokensController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_employee!
  before_action :set_token, only: [:show, :status]
  before_action :check_location_access
  

  def index
    @tokens = Token.for_user(current_user)
                   .includes(order: { order_items: :food_item })
                   .order(created_at: :desc)
                   .page(params[:page]).per(10)

    # Find today's active/partially redeemed token for the banner
    @active_token = @tokens.find { |t| t.active? || t.partially_redeemed? }
  end

  def show
    @order       = @token.order
    @food_items  = @order.food_items
    @order_items = @order.order_items
                         .includes(:food_item,
                                   redemption_requests: :vendor)
                         .order("food_items.sort_order")

    @pending_requests = @token.redemption_requests
                              .pending
                              .includes(:vendor, order_item: :food_item)
                              .order(created_at: :asc)
  end

  # GET /employee/tokens/:id/status — polled by JS every 5s
  def status
    order_items_data = @token.order.order_items.includes(:food_item).map do |oi|
      {
        item_code:      oi.item_code,
        category:       oi.food_item.category,
        category_label: oi.food_item.category_label,
        redeemed:       oi.redeemed?,
        redeemed_at:    oi.redeemed_at&.strftime("%I:%M %p")
      }
    end

    pending = @token.redemption_requests
                    .pending
                    .includes(:vendor, order_item: :food_item)
                    .map do |req|
      {
        id:           req.id,
        vendor_name:  req.vendor.name,
        category:     req.order_item.food_item.category_label,
        item_code:    req.order_item.item_code
      }
    end

    render json: {
      token_status:       @token.status,
      fully_redeemed:     @token.fully_redeemed?,
      partially_redeemed: @token.partially_redeemed?,
      expired:            @token.expired?,
      order_items:        order_items_data,
      pending_requests:   pending
    }
  end

  private

  def set_token
    @token = Token.for_user(current_user)
                  .includes(order: { order_items: [:food_item,
                                                    { redemption_requests: :vendor }] })
                  .find_by(id: params[:id])
    redirect_to employee_tokens_path, alert: "Token not found." unless @token
  end

  def ensure_employee!
    redirect_to root_path, alert: "Access denied." unless current_user.employee?
  end
end
