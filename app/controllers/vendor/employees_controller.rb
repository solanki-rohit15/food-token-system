class Vendor::EmployeesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_vendor!

  def index
    @employees = User.employees.active
                     .includes(:employee_profile, orders: [:food_items, :token])
                     .order(:name)
  end

  def show
    @employee = User.employees.find(params[:id])
    @today_order = @employee.orders.today.includes(:food_items, :token).first
  end
end
