class Admin::TokensController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!

  def index
    @date   = safe_parse_date(params[:date]) || Date.current
    @tokens = Token.for_date(@date)
                   .includes(order: [:user, { order_items: :food_item },
                                     { food_items: [] }])
                   .order(created_at: :desc)

    if params[:status].present?
      @tokens = @tokens.where(status: params[:status])
    end

    if params[:search].present?
      q = "%#{params[:search]}%"
      @tokens = @tokens.joins(order: :user)
                       .where("users.name ILIKE ? OR users.email ILIKE ? OR tokens.token_number ILIKE ?",
                              q, q, q)
    end

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

end
