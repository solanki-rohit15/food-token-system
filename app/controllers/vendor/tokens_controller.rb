class Vendor::TokensController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_vendor!
  before_action :set_token, only: [:show, :send_redemption_request, :redeem]

  def index
    date = params[:date].present? ? Date.parse(params[:date]) : Date.current

    @tokens = Token.for_date(date)
                   .includes(order: [:user, :food_items])
                   .order(created_at: :desc)

    @tokens = case params[:status]
              when "active"   then @tokens.active
              when "redeemed" then @tokens.redeemed
              when "expired"  then @tokens.expired
              else                 @tokens
              end

    if params[:search].present?
      q = "%#{params[:search]}%"
      @tokens = @tokens.joins(order: :user)
                       .where("users.name ILIKE ? OR users.email ILIKE ?", q, q)
    end

    @tokens = @tokens.page(params[:page]).per(20)
    @date   = date
  end

  def show
    @order      = @token.order
    @employee   = @token.user
    @food_items = @token.food_items
  end

  def redeem
    unless @token.redeemable?
      redirect_to vendor_token_path(@token), alert: "Token is not redeemable (#{@token.status})."
      return
    end

    if @token.redeem!(current_user)
      ActionCable.server.broadcast("token_#{@token.id}", {
        event:   "redeemed",
        message: "Your token was redeemed by #{current_user.name}"
      })
      redirect_to vendor_tokens_path, notice: "Token redeemed for #{@token.user.name}! ✅"
    else
      redirect_to vendor_token_path(@token), alert: "Could not redeem token."
    end
  end

  def send_redemption_request
    unless @token.redeemable?
      render json: { success: false, message: "Token is not redeemable" } and return
    end

    ActionCable.server.broadcast("user_#{@token.user.id}", {
      event:    "redemption_request",
      token_id: @token.id,
      vendor:   current_user.name,
      items:    @token.summary
    })

    render json: { success: true, message: "Redemption request sent to employee" }
  end

  private

  def set_token
    @token = Token.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to vendor_tokens_path, alert: "Token not found."
  end

  def ensure_vendor!
    redirect_to root_path, alert: "Access denied." unless current_user.vendor?
  end
end
