class Employee::FoodSelectionsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_employee!
  before_action :check_location_access
  before_action :redirect_if_already_ordered, only: [:new, :create]

  def new
    @meal_settings     = MealSetting.all.index_by(&:meal_type)
    @active_categories = FoodItem.active.ordered.index_by(&:category)
  end

  def create
    selected_categories = Array(params[:categories])
                            .map(&:to_s)
                            .uniq
                            .select { |c| FoodItem::CATEGORIES.key?(c) }

    if selected_categories.blank?
      redirect_to new_employee_food_selection_path, alert: "Please select at least one meal."
      return
    end

    token = place_order(selected_categories)

    if token
      redirect_to employee_token_path(token), notice: "Your food token has been generated! 🎉"
    else
      redirect_to new_employee_food_selection_path,
                  alert: "Could not place order. Please select available meals."
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to new_employee_food_selection_path, alert: e.message
  end

  private

  def redirect_if_already_ordered
    if current_user.ordered_today?
      redirect_to employee_tokens_path, notice: "You already have an order for today."
    end
  end

  def place_order(selected_categories)
    token = nil
    ActiveRecord::Base.transaction do
      order       = current_user.orders.create!(date: Date.current)
      valid_items = FoodItem.active.where(category: selected_categories).select(&:available_now?)

      raise ActiveRecord::Rollback if valid_items.empty?

      valid_items.each { |item| order.order_items.create!(food_item: item) }
      token = order.generate_token!
    end
    token
  end

end