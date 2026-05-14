class Employee::TokensController < ApplicationController
  before_action :require_employee!
  before_action :check_location_access
  before_action :set_token, only: [ :show, :status ]

  def index
    @tokens = Token.for_user(current_user)
                   .distinct
                   .includes(order: { order_items: :food_item })
                   .order(created_at: :desc)
                   .page(params[:page]).per(10)

    @active_token         = @tokens.detect(&:redeemable?)
  end

  def show
    @order_item = @token.order_item
    @order      = @order_item.order
    @food_item  = @order_item.food_item

    @pending_requests = @token.redemption_requests
                              .pending
                              .includes(:vendor, order_item: :food_item)
                              .order(created_at: :asc)
  end

  def status
    render json: @token.status_payload
  end

  private

  def set_token
    @token = Token.for_user(current_user)
                  .includes(order_item: [ :food_item, :order,
                                          { redemption_requests: :vendor } ])
                  .find_by(id: params[:id])
    redirect_to employee_tokens_path, alert: "Token not found." unless @token
  end
end
