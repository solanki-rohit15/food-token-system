class Vendor::DashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_vendor!

  def index
    @view_mode = params[:view].presence_in(%w[daily monthly]) || "daily"

    if @view_mode == "monthly"
      @month      = parse_month(params[:month]) || Date.current.beginning_of_month
      @end_month  = @month.end_of_month
      @date_range = @month..[@end_month, Date.current].min

      @monthly_summary  = category_redemption_summary(@date_range)
      @daily_breakdown  = build_daily_breakdown(@month, @end_month)
    else
      @date            = parse_date(params[:date]) || Date.current
      @today_tokens    = Token.for_date(@date).includes(order: [:user, :food_items])
      @redeemed_tokens = @today_tokens.redeemed
      @meal_summary    = category_redemption_summary(@date..@date, redeemed_only: true)
      @recent_scans    = @redeemed_tokens.order(redeemed_at: :desc).limit(8)

      @stats = {
        total_selected: @today_tokens.count,
        redeemed:       @redeemed_tokens.count,
        unredeemed:     @today_tokens.active.count,
        expired:        @today_tokens.expired.count,
        total_amount:   @meal_summary.values.sum { |v| v[:amount] }
      }
    end
  end

  private

  # Single SQL query: counts redeemed order_items per category for a date range
  def category_redemption_summary(date_range, redeemed_only: true)
    counts = OrderItem
      .joins(food_item: {}, order: :token)
      .where(orders: { date: date_range })
      .then { |q| redeemed_only ? q.where(tokens: { status: Token.statuses[:redeemed] }) : q }
      .group("food_items.category")
      .count

    prices = MealSetting.all.index_by(&:meal_type)

    FoodItem::CATEGORIES.each_with_object({}) do |(cat, info), hash|
      price = prices[cat]&.price.to_f
      count = counts[cat].to_i
      hash[cat] = {
        label:  info[:label],
        icon:   info[:icon],
        color:  info[:color],
        count:  count,
        price:  price,
        amount: (count * price).round(2)
      }
    end
  end

  def build_daily_breakdown(month_start, month_end)
    (month_start..([month_end, Date.current].min)).map do |date|
      summary = category_redemption_summary(date..date, redeemed_only: true)
      { date: date, summary: summary, total: summary.values.sum { |v| v[:amount] } }
    end.reverse
  end

  def parse_date(str)
    Date.parse(str.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def parse_month(str)
    Date.parse("#{str}-01")
  rescue ArgumentError, TypeError
    nil
  end

  def ensure_vendor!
    redirect_to root_path, alert: "Access denied." unless current_user.vendor?
  end
end
