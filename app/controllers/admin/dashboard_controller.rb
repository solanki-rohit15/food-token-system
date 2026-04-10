class Admin::DashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin!

  def index
    @stats = {
      total_employees: User.employees.count,
      total_vendors:   User.vendors.count,
      today_orders:    Order.today.count,
      today_redeemed:  Token.today.redeemed.count,
      today_active:    Token.today.active.count,
      today_expired:   Token.today.expired.count,
      food_items:      FoodItem.active.count
    }

    @recent_tokens = Token.today
                          .includes(order: [:user, :food_items])
                          .order(created_at: :desc)
                          .limit(10)

    @meal_breakdown = FoodItem::CATEGORIES.map do |cat, info|
      {
        category: cat,
        label:    info[:label],
        icon:     info[:icon],
        count:    OrderItem.joins(:food_item, order: :token)
                           .where(food_items: { category: cat.to_s })
                           .where(orders: { date: Date.current })
                           .count
      }
    end

    @weekly_data = (6.days.ago.to_date..Date.current).map do |date|
      {
        date:     date.strftime("%a"),
        orders:   Order.for_date(date).count,
        redeemed: Token.for_date(date).redeemed.count
      }
    end
  end

  private

  def ensure_admin!
    redirect_to root_path, alert: "Access denied." unless current_user.admin?
  end
end
