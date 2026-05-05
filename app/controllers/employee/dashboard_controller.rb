class Employee::DashboardController < ApplicationController
  before_action :require_employee!
  before_action :check_location_access  # enforces GPS gate on every load

  def index
    @today_orders  = current_user.orders.today.includes(:food_items, :token).order(created_at: :asc)
    @today_tokens  = @today_orders.map(&:token).compact
    # Split so the view knows whether any token is still usable today
    @active_today_tokens  = @today_tokens.reject(&:expired?)
    @expired_today_tokens = @today_tokens.select(&:expired?)
    @active_token  = @active_today_tokens.find { |t| t.status == "active" }
    @food_items    = FoodItem.active.ordered
    @food_by_cat   = @food_items.group_by(&:category)
    @meal_settings = MealSetting.all.index_by(&:meal_type)
    @recent_tokens = Token.for_user(current_user).includes(order: :food_items)
                          .order(created_at: :desc).limit(10)
    @ordered_categories = @today_orders.reject { |o| o.token&.expired? }
                                       .flat_map { |o| o.food_items.map(&:category) }.uniq
    @stats = {
      total_orders:    current_user.orders.count,
      this_month:      current_user.orders.this_month.count,
      redeemed_tokens: Token.for_user(current_user).redeemed.count
    }
  end
end
