require "csv"

class Admin::ReportsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!

  def index
    @date     = safe_parse_date(params[:date]) || Date.current
    @tokens   = Token.for_date(@date).includes(order: [:user, :food_items]).order(created_at: :desc)
    @total    = @tokens.count
    @redeemed = @tokens.redeemed.count
    @active   = @tokens.active.count
    @expired  = @tokens.expired_effective.count
  end

  def daily
    @date   = safe_parse_date(params[:date]) || Date.current
    @orders = Order.for_date(@date).includes(:user, :food_items, :token).order(created_at: :desc)
  end

  def monthly
    @month     = safe_parse_date(params[:month]) || Date.current.beginning_of_month
    @end_month = @month.end_of_month
    @orders    = Order.where(date: @month..@end_month)
                      .includes(:user, :food_items, :token)
                      .order(date: :desc, created_at: :desc)

    @daily_stats = (@month..[@end_month, Date.current].min).map do |date|
      day_tokens = Token.for_date(date)
      {
        date:     date,
        orders:   Order.for_date(date).count,
        redeemed: day_tokens.redeemed.count,
        expired:  day_tokens.expired_effective.count
      }
    end
  end

  def employee_wise
    @date        = safe_parse_date(params[:date]) || Date.current
    @employees   = User.employees.active.includes(orders: [:food_items, :token]).order(:name)
    @date_orders = Order.for_date(@date).includes(:user, :food_items, :token).order(created_at: :desc)
  end

  def export
    @date   = safe_parse_date(params[:date]) || Date.current
    @tokens = Token.for_date(@date).includes(order: [:user, :food_items])

    send_data daily_csv(@tokens),
              filename: "report_daily_#{@date}.csv",
              type: "text/csv; charset=utf-8",
              disposition: "attachment"
  end

  def export_monthly
    @month     = safe_parse_month(params[:month]) || Date.current.beginning_of_month
    @end_month = @month.end_of_month
    @orders    = Order.where(date: @month..@end_month)
                      .includes(:user, :token, :food_items)
                      .order(date: :asc, created_at: :asc)

    send_data monthly_csv(@orders),
              filename: "report_monthly_#{@month.strftime('%Y_%m')}.csv",
              type: "text/csv; charset=utf-8",
              disposition: "attachment"
  end

  private

  def daily_csv(tokens)
    CSV.generate(headers: true) do |csv|
      csv << ["Date", "Employee", "Email", "Department", "Categories", "Token Number", "Status", "Redeemed At"]
      tokens.each do |token|
        csv << [
          token.order&.date,
          token.user&.name,
          token.user&.email,
          token.user&.employee_profile&.department,
          token.food_items.map(&:category_label).join(", "),
          token.token_number,
          token.status,
          token.redeemed_at&.strftime("%I:%M %p")
        ]
      end
    end
  end

  def monthly_csv(orders)
    CSV.generate(headers: true) do |csv|
      csv << ["Date", "Employee", "Email", "Department", "Categories", "Token Number", "Token Status", "Redeemed At"]
      orders.each do |order|
        token = order.token
        csv << [
          order.date,
          order.user&.name,
          order.user&.email,
          order.user&.employee_profile&.department,
          order.food_items.map(&:category_label).join(", "),
          token&.token_number,
          token&.status,
          token&.redeemed_at&.strftime("%I:%M %p")
        ]
      end
    end
  end
end
