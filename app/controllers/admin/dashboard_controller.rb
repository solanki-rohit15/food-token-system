class Admin::DashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!

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

    meal_counts = OrderItem.joins(:food_item, order: :token)
                           .where(orders: { date: Date.current })
                           .group("food_items.category")
                           .count

    @meal_breakdown = FoodItem::CATEGORIES.map do |cat, info|
      {
        category: cat,
        label:    info[:label],
        icon:     info[:icon],
        count:    meal_counts[cat.to_s].to_i
      }
    end

    weekly_range = 6.days.ago.to_date..Date.current
    order_counts = Order.where(date: weekly_range).group(:date).count
    redeemed_counts = Token.joins(:order)
                           .where(orders: { date: weekly_range }, status: :redeemed)
                           .group("orders.date")
                           .count

    @weekly_data = weekly_range.map do |date|
      {
        date:     date.strftime("%a"),
        orders:   order_counts[date].to_i,
        redeemed: redeemed_counts[date].to_i
      }
    end
  end
end
