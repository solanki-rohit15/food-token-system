class Employee::FoodSelectionsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_employee!

  def new
    if current_user.ordered_today?
      redirect_to employee_tokens_path, notice: "You already have an order for today."
      return
    end

    @food_items    = FoodItem.active.ordered
    @food_by_cat   = @food_items.group_by(&:category)
    @meal_settings = MealSetting.all.index_by(&:meal_type)
  end

  def create
    if current_user.ordered_today?
      redirect_to employee_tokens_path, alert: "You already have an order for today."
      return
    end

    food_item_ids = Array(params[:food_item_ids]).map(&:to_i).uniq

    if food_item_ids.blank?
      redirect_to new_employee_food_selection_path, alert: "Please select at least one item."
      return
    end

    token = nil

    ActiveRecord::Base.transaction do
      order = current_user.orders.create!(date: Date.current)

      valid_items = FoodItem.active.where(id: food_item_ids).select(&:available_now?)

      if valid_items.empty?
        raise ActiveRecord::Rollback, "No valid/available items selected"
      end

      valid_items.each do |item|
        order.order_items.create!(food_item: item)
      end

      token = order.generate_token!
    end

    if token
      redirect_to employee_token_path(token), notice: "Your food token has been generated! 🎉"
    else
      redirect_to new_employee_food_selection_path,
        alert: "Could not place order. Please select available items."
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to new_employee_food_selection_path, alert: e.message
  end

  private

  def ensure_employee!
    redirect_to root_path, alert: "Access denied." unless current_user.employee?
  end
end
