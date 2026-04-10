class Vendor::EmployeesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_vendor!

  def index
    @employees = User.employees.active
                     .includes(:employee_profile, orders: [:food_items, :token])
                     .order(:name)
  end

  def show
    @employee = User.employees.find(params[:id])
    @today_order = @employee.orders.today.includes(:food_items, :token).first
  end

  private

  def ensure_vendor!
    redirect_to root_path, alert: "Access denied." unless current_user.vendor?
  end
end
