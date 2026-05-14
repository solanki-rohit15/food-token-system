require "csv"

class Admin::ReportsController < ApplicationController
  before_action :require_admin!

  def index
    @date = safe_parse_date(params[:date]) || Date.current

    base_scope = Token.for_date(@date)

    @tokens = base_scope
                .includes(order_item: [ :food_item, order: :user ])
                .order(created_at: :desc)

    counts = base_scope.group(:status).count

    @total    = base_scope.count
    @redeemed = counts["redeemed"].to_i
    @active   = counts["active"].to_i
    @expired  = counts["expired"].to_i
  end

  def daily
    @date   = safe_parse_date(params[:date]) || Date.current
    @tokens = Token.for_date(@date)
                   .includes(order_item: [ :food_item, order: :user ])
                   .order(created_at: :desc)
  end

  def monthly
    @month_start = safe_parse_date(params[:month]) || Date.current.beginning_of_month
    @month_end   = @month_start.end_of_month

    @tokens = Token.joins(order_item: :order)
                   .where(orders: { date: @month_start..@month_end })
                   .includes(order_item: [ :food_item, order: :user ])
                   .order("orders.date DESC, tokens.created_at DESC")

    @daily_stats    = build_monthly_daily_stats(@month_start, @month_end)
    @monthly_counts = build_monthly_token_counts(@tokens)
  end

  def employee_wise
    @date        = safe_parse_date(params[:date]) || Date.current
    @date_tokens = Token.for_date(@date)
                        .includes(order_item: [ :food_item, order: :user ])
                        .order(created_at: :desc)
  end

  def export
    date   = safe_parse_date(params[:date]) || Date.current
    tokens = Token.for_date(date).includes(order_item: [ :food_item, order: :user ])

    send_csv(token_csv(tokens), "report_daily_#{date}.csv")
  end

  def export_monthly
    month_start = safe_parse_month(params[:month]) || Date.current.beginning_of_month

    tokens = Token.joins(order_item: :order)
                   .where(orders: { date: month_start..month_start.end_of_month })
                   .includes(order_item: [ :food_item, order: :user ])
                   .order("orders.date ASC, tokens.created_at ASC")

    send_csv(token_csv(tokens), "report_monthly_#{month_start.strftime('%Y_%m')}.csv")
  end

  private

  def build_monthly_daily_stats(month_start, month_end)
    cutoff = [ month_end, Date.current ].min

    order_counts = Order.where(date: month_start..cutoff).group(:date).count

    token_counts = Token.joins(order_item: :order)
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

  def build_monthly_token_counts(tokens)
    redeemed = expired = active = 0
    tokens.each do |t|
      if    t.redeemed? then redeemed += 1
      elsif t.expired?  then expired  += 1
      elsif t.active?   then active   += 1
      end
    end
    { total: tokens.size, redeemed: redeemed, active: active, expired: expired }
  end

  def build_row(token:, order:, user:)
    [
      order&.date,
      user&.name,
      user&.email,
      token&.summary,
      token&.token_number,
      token&.status,
      token&.redeemed_at&.strftime("%I:%M %p")
    ]
  end

  def csv_headers
    [ "Date", "Employee", "Email", "Meal", "Token Number", "Status", "Redeemed At" ]
  end

  def build_csv(collection, header_row, &block)
    CSV.generate(headers: true) do |csv|
      csv << header_row
      collection.each { |record| csv << block.call(record) }
    end
  end

  def send_csv(data, filename)
    send_data(data, filename: filename, type: "text/csv; charset=utf-8", disposition: "attachment")
  end

  def token_csv(tokens)
    build_csv(tokens, csv_headers) do |token|
      build_row(token: token, order: token.order, user: token.user)
    end
  end
end
