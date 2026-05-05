class Vendor::TokensController < ApplicationController
  before_action :require_vendor!
  before_action :set_token, only: [ :show, :status, :send_redemption_request ]

  # GET /vendor/tokens — supports AJAX filter updates (JSON)
  def index
    @date   = safe_parse_date(params[:date]) || Date.current
    @tokens = build_token_scope

    respond_to do |format|
      format.html
      format.json do
        render json: {
          date:       @date.strftime("%Y-%m-%d"),
          date_label: @date == Date.current ? "Today" : @date.strftime("%A, %d %B %Y"),
          total:      @tokens.total_count,
          tokens:     serialize_tokens(@tokens)
        }
      end
    end
  end

  def show
    @order            = @token.order
    @employee         = @order.user
    @order_items      = @order.order_items.includes(:food_item, :redemption_requests)
    @food_items       = @order.food_items
    @pending_requests = @token.redemption_requests.pending.includes(:order_item)
  end

  # GET /vendor/tokens/:id/status
  def status
    render json: @token.status_payload
  end

  # POST /vendor/tokens/:id/send_redemption_request?order_item_id=X
  # Always returns JSON — called via AJAX from scanner.js and token show page
  def send_redemption_request
    order_item = @token.order.order_items
                       .includes(:food_item)
                       .find_by(id: params[:order_item_id])

    return render_error("Item not found for this token.", :not_found) unless order_item
    return render_error("#{order_item.food_item.category_label} has already been redeemed.") if order_item.redeemed?
    return render_error("Token is not redeemable (#{@token.status}).") unless @token.redeemable?
    if RedemptionRequest.exists?(order_item_id: order_item.id, status: :pending)
      return render_error("A request is already pending for #{order_item.food_item.category_label}.")
    end

    req = RedemptionRequest.create!(
      token:      @token,
      order_item: order_item,
      vendor:     current_user,
      status:     :pending
    )

    ActionCable.server.broadcast("user_#{@token.user.id}", {
      event:                 "redemption_request",
      redemption_request_id: req.id,
      token_id:              @token.id,
      item_code:             order_item.item_code,
      category:              order_item.food_item.category_label,
      vendor_name:           current_user.name,
      vendor_stall:          current_user.vendor_profile&.stall_name,
      message:               "#{current_user.name} wants to redeem #{order_item.food_item.category_label}"
    })

    render json: { success: true, message: "Request sent. Waiting for employee approval." }

  rescue ActiveRecord::RecordInvalid => e
    render_error(e.message)
  end

  private

  def build_token_scope
    scope = Token.for_date(@date)
                 .includes(order: [ :user, :food_items ])
                 .order(created_at: :desc)

    scope = scope.where(status: params[:status]) if params[:status].present?

    if params[:search].present?
      q = "%#{params[:search]}%"
      scope = scope.joins(order: :user)
                   .where("users.name ILIKE ? OR users.email ILIKE ? OR tokens.token_number ILIKE ?", q, q, q)
    end

    scope.page(params[:page]).per(20)
  end

  def serialize_tokens(tokens)
    tokens.map do |token|
      {
        id:            token.id,
        token_number:  token.token_number,
        status:        token.status,
        created_at:    token.created_at.strftime("%I:%M %p"),
        redeemed_at:   token.redeemed_at&.strftime("%I:%M %p"),
        employee_name: token.user.name,
        employee_initials: token.user.initials,
        categories:    token.order.items_label,
        show_path:     Rails.application.routes.url_helpers.vendor_token_path(token)
      }
    end
  end

  def set_token
    @token = Token.includes(order: [ :user, :food_items, :order_items ]).find_by(id: params[:id])
    if @token.nil?
      respond_to do |format|
        format.html { redirect_to vendor_tokens_path, alert: "Token not found." }
        format.json { render json: { error: "Token not found." }, status: :not_found }
      end
    end
  end

  def render_error(message, status = :unprocessable_entity)
    render json: { success: false, message: message }, status: status
  end
end
