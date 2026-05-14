class Admin::DashboardController < ApplicationController
  before_action :require_admin!

  def index
    @stats          = build_stats
    @recent_tokens  = fetch_recent_tokens
    @meal_breakdown = build_meal_breakdown
    @weekly_data    = build_weekly_data
  end

  private

  def build_stats
    today_token_counts = Token.today.group(:status).count

    {
      total_employees: User.employees.count,
      total_vendors:   User.vendors.count,
      today_orders:    Order.today.count,
      today_redeemed:  today_token_counts["redeemed"].to_i,
      today_active:    today_token_counts["active"].to_i,
      today_expired:   today_token_counts["expired"].to_i,
      food_items:      FoodItem.active.count
    }
  end

  def fetch_recent_tokens
    Token.today
         .includes(order_item: [ :food_item, order: :user ])
         .order(created_at: :desc)
         .limit(10)
  end

  def build_meal_breakdown
    meal_counts = OrderItem
      .joins(:food_item, :token, :order)
      .where(orders: { date: Date.current })
      .group("food_items.category")
      .count

    FoodItem::CATEGORIES.map do |cat, info|
      { category: cat, label: info[:label], icon: info[:icon], count: meal_counts[cat].to_i }
    end
  end

  def build_weekly_data
    weekly_range  = 6.days.ago.to_date..Date.current
    order_counts  = Order.where(date: weekly_range).group(:date).count
    redeemed_counts = Token
      .joins(order_item: :order)
      .where(orders: { date: weekly_range }, status: :redeemed)
      .group("orders.date")
      .count

    weekly_range.map do |date|
      { date: date.strftime("%a"), orders: order_counts[date].to_i, redeemed: redeemed_counts[date].to_i }
    end
  end
end
