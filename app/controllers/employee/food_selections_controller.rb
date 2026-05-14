class Employee::FoodSelectionsController < ApplicationController
  before_action :require_employee!
  before_action :check_location_access
  before_action :redirect_if_already_ordered, only: [ :new, :create ]

  def new
    @meal_settings      = MealSetting.all.index_by(&:meal_type)
    @active_categories  = FoodItem.active.ordered.index_by(&:category)
    @ordered_categories = current_user.orders.today
                                      .joins(tokens: { order_item: :food_item })
                                      .where.not(tokens: { status: Token.statuses[:expired] })
                                      .pluck('food_items.category').uniq
  end

  def create
    previously_ordered = current_user.orders.today
                                     .joins(tokens: { order_item: :food_item })
                                     .where.not(tokens: { status: Token.statuses[:expired] })
                                     .pluck('food_items.category')
    selected_categories = Array(params[:categories])
                            .map(&:to_s)
                            .uniq
                            .select { |c| FoodItem::CATEGORIES.key?(c) }
                            .reject { |c| previously_ordered.include?(c) }

    if selected_categories.blank?
      redirect_to new_employee_food_selection_path, alert: "Please select at least one available meal that you haven't ordered yet today."
      return
    end

    success = place_order(selected_categories)

    if success
      redirect_to employee_tokens_path, notice: "Your food tokens have been generated! 🎉"
    else
      redirect_to new_employee_food_selection_path,
                  alert: "Could not place order. Please select available meals."
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to new_employee_food_selection_path, alert: e.message
  end

  private

  def redirect_if_already_ordered
    ordered_categories = current_user.orders.today
                                     .joins(tokens: { order_item: :food_item })
                                     .where.not(tokens: { status: Token.statuses[:expired] })
                                     .pluck('food_items.category').uniq
    available_categories = FoodItem.active.pluck(:category).uniq
    
    if available_categories.any? && ordered_categories.count >= available_categories.count
      redirect_to employee_tokens_path, notice: "You have already ordered all available meals for today."
    end
  end

  def place_order(selected_categories)
    success = false
    ActiveRecord::Base.transaction do
      order       = current_user.orders.create!(date: Date.current)
      valid_items = FoodItem.active.where(category: selected_categories).select(&:available_now?)

      raise ActiveRecord::Rollback if valid_items.empty?

      valid_items.each { |item| order.order_items.create!(food_item: item) }
      # Token generation now happens in OrderItem after_create
      success = true
    end
    success
  end
end
