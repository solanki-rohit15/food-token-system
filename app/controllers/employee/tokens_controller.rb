class Employee::TokensController < ApplicationController
  before_action :authenticate_user!
  before_action :require_employee!
  before_action :check_location_access
  before_action :set_token, only: [:show, :status]

  def index
    @tokens = Token.for_user(current_user)
                   .includes(order: { order_items: :food_item })
                   .order(created_at: :desc)
                   .page(params[:page]).per(10)

    @redeemed_item_counts = redeemed_item_counts_for(@tokens)
    @active_token         = @tokens.detect { |t| t.active? || t.partially_redeemed? }
  end

  def show
    @order    = @token.order
    @food_items  = @order.food_items
    @order_items = @order.order_items
                         .includes(:food_item, redemption_requests: :vendor)
                         .order("food_items.sort_order")

    @pending_requests = @token.redemption_requests
                              .pending
                              .includes(:vendor, order_item: :food_item)
                              .order(created_at: :asc)
  end

  def status
    render json: build_status_payload
  end

  private

  def set_token
    @token = Token.for_user(current_user)
                  .includes(order: { order_items: [:food_item,
                                                    { redemption_requests: :vendor }] })
                  .find_by(id: params[:id])
    redirect_to employee_tokens_path, alert: "Token not found." unless @token
  end

  def redeemed_item_counts_for(tokens)
    order_ids = tokens.map(&:order_id)
    return {} unless order_ids.any?

    OrderItem.where(order_id: order_ids)
             .where.not(redeemed_at: nil)
             .group(:order_id)
             .count
  end

  def build_status_payload
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
      { id: req.id, vendor_name: req.vendor.name,
        category: req.order_item.food_item.category_label,
        item_code: req.order_item.item_code }
    end

    {
      token_status:       @token.status,
      fully_redeemed:     @token.fully_redeemed?,
      partially_redeemed: @token.partially_redeemed?,
      expired:            @token.expired?,
      order_items:        order_items_data,
      pending_requests:   pending
    }
  end
end