require "csv"

class Admin::ReportsController < ApplicationController
  before_action :require_admin!

  def index
    @date = safe_parse_date(params[:date]) || Date.current

    base_scope = Token.for_date(@date)

    @tokens = base_scope
                .includes(order: [ :user, :food_items ])
                .order(created_at: :desc)

    counts = base_scope.group(:status).count

    @total    = base_scope.count
    @redeemed = counts["redeemed"].to_i
    @active   = counts["active"].to_i
    @expired  = counts["expired"].to_i
  end

  def daily
    @date   = safe_parse_date(params[:date]) || Date.current
    @orders = Order.for_date(@date)
                   .includes(:user, :food_items, :token)
                   .order(created_at: :desc)
  end

  def monthly
    @month_start = safe_parse_date(params[:month]) || Date.current.beginning_of_month
    @month_end   = @month_start.end_of_month

    @orders = Order.where(date: @month_start..@month_end)
                   .includes(:user, :food_items, :token)
                   .order(date: :desc, created_at: :desc)

    @daily_stats    = build_monthly_daily_stats(@month_start, @month_end)
    @monthly_counts = build_monthly_token_counts(@orders)
  end

  def employee_wise
    @date        = safe_parse_date(params[:date]) || Date.current
    @employees   = User.employees.active
                       .includes(orders: [ :food_items, :token ])
                       .order(:name)

    @date_orders = Order.for_date(@date)
                        .includes(:user, :food_items, :token)
                        .order(created_at: :desc)
  end

  def export
    date   = safe_parse_date(params[:date]) || Date.current
    tokens = Token.for_date(date).includes(order: [ :user, :food_items ])

    send_csv(daily_csv(tokens), "report_daily_#{date}.csv")
  end

  def export_monthly
    month_start = safe_parse_month(params[:month]) || Date.current.beginning_of_month

    orders = Order.where(date: month_start..month_start.end_of_month)
                  .includes(:user, :token, :food_items)
                  .order(date: :asc, created_at: :asc)

    send_csv(monthly_csv(orders), "report_monthly_#{month_start.strftime('%Y_%m')}.csv")
  end

  private

  # ─────────────────────────────────────────────
  # Monthly stats
  # ─────────────────────────────────────────────
  def build_monthly_daily_stats(month_start, month_end)
    cutoff = [ month_end, Date.current ].min

    order_counts = Order.where(date: month_start..cutoff).group(:date).count

    token_counts = Token.joins(:order)
                        .where(orders: { date: month_start..cutoff })
                        .group("orders.date", :status)
                        .count

    (month_start..cutoff).map do |date|
      {
        date:     date,
        orders:   order_counts[date].to_i,
        redeemed: token_counts[[ date, "redeemed" ]].to_i,
        expired:  token_counts[[ date, "expired" ]].to_i +
                  token_counts[[ date, "active" ]].to_i
      }
    end
  end

  # Counts redeemed/active/expired from a preloaded orders collection.
  # Avoids N+1 — tokens are already included via :token.
  def build_monthly_token_counts(orders)
    redeemed = expired = active = 0
    orders.each do |o|
      t = o.token
      next unless t
      if    t.redeemed? then redeemed += 1
      elsif t.expired?  then expired  += 1
      elsif t.active?   then active   += 1
      end
    end
    { total: orders.size, redeemed: redeemed, active: active, expired: expired }
  end

  # ─────────────────────────────────────────────
  # Row builder (SAFE)
  # ─────────────────────────────────────────────
  def build_row(order:, token:, user:)
    [
      order&.date,
      user&.name,
      user&.email,
      order&.items_label,
      token&.token_number,
      token&.status,
      token&.redeemed_at&.strftime("%I:%M %p")
    ]
  end

  # ─────────────────────────────────────────────
  def csv_headers
    [ "Date", "Employee", "Email", "Categories",
     "Token Number", "Status", "Redeemed At" ]
  end

  # ─────────────────────────────────────────────
  # Generic CSV builder
  # ─────────────────────────────────────────────
  def build_csv(collection, header_row, &block)
    raise ArgumentError, "Block required" unless block_given?

    CSV.generate(headers: true) do |csv|
      csv << header_row

      collection.each do |record|
        row = block.call(record)

        unless row.is_a?(Array)
          raise TypeError, "CSV row must be Array, got #{row.class}"
        end

        csv << row
      end
    end
  end

  # ─────────────────────────────────────────────
  def send_csv(data, filename)
    send_data(
      data,
      filename: filename,
      type: "text/csv; charset=utf-8",
      disposition: "attachment"
    )
  end

  # ─────────────────────────────────────────────
  def daily_csv(tokens)
    build_csv(tokens, csv_headers) do |token|
      order = token.order
      user  = order&.user

      build_row(order: order, token: token, user: user)
    end
  end

  def monthly_csv(orders)
    build_csv(orders, csv_headers) do |order|
      token = order.token
      user  = order.user

      build_row(order: order, token: token, user: user)
    end
  end
end
