class Admin::FoodItemsController < ApplicationController
  before_action :require_admin!
  before_action :set_food_item, only: [ :destroy, :toggle_active ]

  def index
    existing = FoodItem.all.index_by(&:category)

    @category_items = FoodItem::CATEGORIES.map do |cat, info|
      { key: cat, info: info, item: existing[cat] }
    end
  end

  def create
    selected = Array(params[:categories])
                 .map(&:to_s)
                 .uniq
                 .select { |c| FoodItem::CATEGORIES.key?(c) }

    ActiveRecord::Base.transaction do
      FoodItem::CATEGORIES.each_with_index do |(cat, _), idx|
        item = FoodItem.find_or_initialize_by(category: cat)
        item.sort_order = idx
        item.active     = selected.include?(cat)
        item.save! if item.changed? || item.new_record?
      end
    end

    render json: {
      success: true,
      message: "Food categories updated.",
      active_categories: FoodItem.where(active: true).pluck(:category)
    }
  rescue ActiveRecord::RecordInvalid => e
    render json: { success: false, message: e.message }, status: :unprocessable_entity
  end

  def toggle_active
    @food_item.update!(active: !@food_item.active?)

    render json: {
      success: true,
      id: @food_item.id,
      active: @food_item.active?,
      message: "Category #{@food_item.active? ? 'activated' : 'deactivated'}."
    }
  rescue ActiveRecord::RecordInvalid => e
    render json: { success: false, message: e.message }, status: :unprocessable_entity
  end

  def destroy
    if @food_item.order_items.exists?
      render json: { success: false, message: "Cannot delete — category has existing orders." },
             status: :unprocessable_entity
    else
      @food_item.destroy!
      render json: { success: true, id: @food_item.id, message: "Category removed." }
    end
  end

  private

  def set_food_item
    @food_item = FoodItem.find(params[:id])
  end
end
