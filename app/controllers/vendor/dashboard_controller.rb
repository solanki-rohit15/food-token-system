class Vendor::DashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_vendor!

  def index
    date = params[:date].present? ? Date.parse(params[:date]) : Date.current

    @today_tokens    = Token.for_date(date).includes(order: [:user, :food_items])
    @active_tokens   = @today_tokens.active
    @redeemed_tokens = @today_tokens.redeemed
    @expired_tokens  = @today_tokens.expired
    @meal_counts     = calculate_meal_counts(date)
    @recent_scans    = @redeemed_tokens.order(redeemed_at: :desc).limit(8)
    @date            = date

    @stats = {
      total_selected: @today_tokens.count,
      redeemed:       @redeemed_tokens.count,
      unredeemed:     @active_tokens.count,
      expired:        @expired_tokens.count
    }
  end

  private

  def calculate_meal_counts(date)
    FoodItem::CATEGORIES.keys.each_with_object({}) do |cat, hash|
      hash[cat] = OrderItem.joins(:food_item, order: :token)
                           .where(food_items: { category: cat.to_s })
                           .where(orders: { date: date })
                           .count
    end
  end

  def ensure_vendor!
    redirect_to root_path, alert: "Access denied." unless current_user.vendor?
  end
end
