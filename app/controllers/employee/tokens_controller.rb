class Employee::TokensController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_employee!
  before_action :set_token, only: [:show]

  def index
    @tokens = Token.for_user(current_user)
                   .includes(:order)
                   .order(created_at: :desc)
                   .page(params[:page])
  end

  def show
    @order = @token.order

    # ✅ SAFE fallback (avoid nil crash)
    @food_items = @order&.food_items || []

    # Optional (if you still use QR somewhere)
    @qr_svg = @token.qr_svg if @token.respond_to?(:qr_svg)

    # ✅ VERY IMPORTANT: include associations to avoid nil errors
    @requests = @token.redemption_requests
                      .includes(:vendor, order_item: :food_item)
                      .order(created_at: :desc)
  end

  private

  def set_token
    @token = Token.for_user(current_user).find_by(id: params[:id])

    # ✅ Prevent crash if token not found
    unless @token
      redirect_to employee_tokens_path, alert: "Token not found"
    end
  end

  def ensure_employee!
    redirect_to root_path unless current_user.employee?
  end
end