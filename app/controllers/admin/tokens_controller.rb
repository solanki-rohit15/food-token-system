class Admin::TokensController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!

  def index
    @date   = safe_parse_date(params[:date]) || Date.current
    @tokens = base_tokens_scope
    @tokens = @tokens.where(status: params[:status]) if params[:status].present?
    @tokens = apply_search(@tokens)                  if params[:search].present?
    @tokens = @tokens.page(params[:page]).per(25)
  end

  def show
    @token    = Token.includes(
                  order: [:user, { order_items: [:food_item, :redeemed_by,
                                                  { redemption_requests: :vendor }] }]
                ).find(params[:id])
    @order    = @token.order
    @employee = @order.user
  end

  private

  def base_tokens_scope
    Token.for_date(@date)
         .includes(order: [:user, { order_items: :food_item }, :food_items])
         .order(created_at: :desc)
  end

  def apply_search(scope)
    q = "%#{params[:search]}%"
    scope.joins(order: :user)
         .where("users.name ILIKE ? OR users.email ILIKE ? OR tokens.token_number ILIKE ?", q, q, q)
  end
end