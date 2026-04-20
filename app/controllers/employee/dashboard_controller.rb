class Employee::DashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_employee!
  before_action :check_location_access  # ← enforces GPS gate on every load

  def index
    @user          = current_user
    @today_order   = @user.today_order
    @active_token  = @today_order&.token
    @food_items    = FoodItem.active.ordered
    @food_by_cat   = @food_items.group_by(&:category)
    @meal_settings = MealSetting.all.index_by(&:meal_type)
    @recent_tokens = Token.for_user(@user).includes(order: :food_items)
                          .order(created_at: :desc).limit(10)
    @stats = {
      total_orders:    @user.orders.count,
      this_month:      @user.orders.this_month.count,
      redeemed_tokens: Token.for_user(@user).redeemed.count
    }
  end

  private

  def ensure_employee!
    redirect_to current_user.dashboard_path, alert: "Access denied." unless current_user.employee?
  end
end
