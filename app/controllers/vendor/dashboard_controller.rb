class Vendor::DashboardController < ApplicationController
  delegate :currency, to: :view_context

  before_action :require_vendor!

  # GET /vendor
  # Supports AJAX via Accept: application/json (from dashboard.js)
  def index
    @view_mode = params[:view].presence_in(%w[daily monthly]) || "daily"

    if @view_mode == "monthly"
      build_monthly_view
    else
      build_daily_view
    end

    respond_to do |format|
      format.html   # initial server render
      format.json { render json: @view_mode == "monthly" ? monthly_json : daily_json }
    end
  end

  private

  # ── Daily ─────────────────────────────────────────────────────────
  def build_daily_view
    @date            = safe_parse_date(params[:date]) || Date.current
    @today_tokens    = Token.for_date(@date).includes(order: [ :user, :food_items ])
    @redeemed_tokens = @today_tokens.redeemed
    @meal_summary    = category_redemption_summary(@date..@date, redeemed_only: true)
    @recent_scans    = @redeemed_tokens.order(redeemed_at: :desc).limit(8)
    @stats = {
      total_selected:  @today_tokens.count,
      redeemed:        @redeemed_tokens.count,
      unredeemed:      @today_tokens.active.count,
      expired:         @today_tokens.expired_effective.count,
      total_amount:    @meal_summary.values.sum { |v| v[:amount] }
    }
  end

  # ── Monthly ───────────────────────────────────────────────────────
  def build_monthly_view
    @month      = safe_parse_month(params[:month]) || Date.current.beginning_of_month
    @end_month  = @month.end_of_month
    @date_range = @month..[ @end_month, Date.current ].min

    @monthly_summary = category_redemption_summary(@date_range)
    @daily_breakdown = build_daily_breakdown(@month, @end_month)
  end

  # ── JSON serialisers ──────────────────────────────────────────────
  def daily_json
    {
      view_mode:    "daily",
      date:         @date.strftime("%Y-%m-%d"),
      date_label:   @date == Date.current ? "Today" : @date.strftime("%A, %d %B %Y"),
      stats:        @stats.merge(total_amount_formatted: currency(@stats[:total_amount])),
      meal_summary: serialise_meal_summary(@meal_summary),
      recent_scans: @recent_scans.map { |t| serialise_scan(t) }
    }
  end

  def monthly_json
    {
      view_mode:       "monthly",
      month:           @month.strftime("%Y-%m"),
      month_label:     @month.strftime("%B %Y"),
      monthly_summary: serialise_meal_summary(@monthly_summary),
      daily_breakdown: @daily_breakdown.map do |day|
        {
          date:            day[:date].strftime("%Y-%m-%d"),
          date_label:      day[:date].strftime("%d %b"),
          total:           day[:total],
          total_formatted: currency(day[:total]),
          summary:         serialise_meal_summary(day[:summary])
        }
      end
    }
  end

  def serialise_meal_summary(summary)
    return [] unless summary
    summary.map do |cat, data|
      data.merge(
        cat:              cat,
        amount_formatted: currency(data[:amount]),
        price_formatted:  currency(data[:price])
      )
    end
  end

  def serialise_scan(token)
    {
      employee_name:     token.user.name,
      employee_initials: token.user.initials,
      categories:        token.order.items_label,
      token_number:      token.token_number,
      redeemed_at:       token.redeemed_at&.strftime("%I:%M %p")
    }
  end

  # ── Queries ───────────────────────────────────────────────────────

  # One SQL query — counts per category for a date range
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

  # One SQL for the full month — groups by date × category
  def build_daily_breakdown(month_start, month_end)
    range = month_start..[ month_end, Date.current ].min

    # Single query for all days × categories
    all_counts = OrderItem
      .joins(food_item: {}, order: :token)
      .where(orders: { date: range }, tokens: { status: Token.statuses[:redeemed] })
      .group("orders.date", "food_items.category")
      .count
    # all_counts = { [Date, "lunch"] => 5, [Date, "breakfast"] => 3, ... }

    prices = MealSetting.all.index_by(&:meal_type)

    range.map do |date|
      summary = FoodItem::CATEGORIES.each_with_object({}) do |(cat, info), h|
        price = prices[cat]&.price.to_f
        count = all_counts[ [ date, cat ] ].to_i
        h[cat] = { label: info[:label], icon: info[:icon], color: info[:color],
                   count: count, price: price, amount: (count * price).round(2) }
      end
      { date: date, summary: summary, total: summary.values.sum { |v| v[:amount] } }
    end.reverse
  end

end
