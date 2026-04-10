class Employee::TokensController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_employee!
  before_action :set_token, only: [:show, :confirm_redemption]

  def index
    @tokens = Token.for_user(current_user)
                   .includes(order: :food_items)
                   .order(created_at: :desc)
                   .page(params[:page]).per(10)
    @active_token = @tokens.find(&:active?)
  end

  def show
    @order      = @token.order
    @food_items = @order.food_items
    @qr_svg     = @token.qr_svg
  end

  def confirm_redemption
    if @token.redeemable?
      @token.update!(status: :redeemed, redeemed_at: Time.current)
      ActionCable.server.broadcast("token_#{@token.id}",
        { event: "redeemed", message: "Token successfully redeemed!" })

      respond_to do |format|
        format.html { redirect_to employee_token_path(@token), notice: "Token redeemed!" }
        format.json { render json: { success: true } }
      end
    else
      respond_to do |format|
        format.html { redirect_to employee_token_path(@token), alert: "Token cannot be redeemed." }
        format.json { render json: { success: false, message: "Token cannot be redeemed" }, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_token
    @token = Token.for_user(current_user).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to employee_tokens_path, alert: "Token not found."
  end

  def ensure_employee!
    redirect_to root_path unless current_user.employee?
  end
end
