require "csv"

class Admin::ReportsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin!

  def index
    @date     = parse_date(params[:date]) || Date.current
    @tokens   = Token.for_date(@date).includes(order: [:user, :food_items]).order(created_at: :desc)
    @total    = @tokens.count
    @redeemed = @tokens.redeemed.count
    @active   = @tokens.active.count
    @expired  = @tokens.expired.count
  end

  def daily
    @date   = parse_date(params[:date]) || Date.current
    @orders = Order.for_date(@date).includes(:user, :food_items, :token).order(created_at: :desc)
  end

  def monthly
    @month     = parse_date(params[:month]) || Date.current.beginning_of_month
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
        expired:  day_tokens.expired.count
      }
    end
  end

  def employee_wise
    @date        = parse_date(params[:date]) || Date.current
    @employees   = User.employees.active.includes(orders: [:food_items, :token]).order(:name)
    @date_orders = Order.for_date(@date).includes(:user, :food_items, :token).order(created_at: :desc)
  end

  def export
    @date   = parse_date(params[:date]) || Date.current
    @tokens = Token.for_date(@date).includes(order: [:user, :food_items])

    csv = CSV.generate(headers: true) do |row|
      row << ["Date", "Employee", "Email", "Department",
              "Categories", "Token Number", "Status", "Redeemed At"]
      @tokens.each do |t|
        row << [
          t.order.date,
          t.user.name,
          t.user.email,
          t.user.employee_profile&.department,
          t.food_items.map(&:category_label).join(", "),
          t.token_number,
          t.status,
          t.redeemed_at&.strftime("%H:%M")
        ]
      end
    end

    send_data csv, filename: "report_#{@date}.csv", type: "text/csv"
  end

  private

  def parse_date(str)
    Date.parse(str.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def ensure_admin!
    redirect_to root_path, alert: "Access denied." unless current_user.admin?
  end
end
