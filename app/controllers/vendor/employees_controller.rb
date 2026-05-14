class Vendor::EmployeesController < ApplicationController
  before_action :require_vendor!

  def index
    @tokens = Token.today
                   .includes(order_item: [ :food_item, order: :user ])
                   .order("users.name ASC")
  end

  def show
    @employee = User.employees.find(params[:id])
    @tokens = Token.for_user(@employee).today
                   .includes(order_item: :food_item)
                   .order(created_at: :asc)
  end
end
