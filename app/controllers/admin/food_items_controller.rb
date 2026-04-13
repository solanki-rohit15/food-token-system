class Admin::FoodItemsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin!
  before_action :set_food_item, only: [:destroy, :toggle_active]

  def index
    @category_items = FoodItem::CATEGORIES.map do |cat, info|
      { key: cat, info: info, item: FoodItem.find_by(category: cat) }
    end
  end

  # POST /admin/food_items — checkbox form activates/deactivates categories
  def create
    selected = Array(params[:categories]).map(&:to_s).uniq
                                         .select { |c| FoodItem::CATEGORIES.key?(c) }

    ActiveRecord::Base.transaction do
      FoodItem::CATEGORIES.each_with_index do |(cat, _), idx|
        item = FoodItem.find_or_initialize_by(category: cat)
        item.sort_order = idx

        if selected.include?(cat)
          item.active = true
          item.save!
        elsif item.persisted?
          item.update!(active: false)
        end
      end
    end

    redirect_to admin_food_items_path, notice: "Food categories updated successfully."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to admin_food_items_path, alert: e.message
  end

  def toggle_active
    @food_item.update!(active: !@food_item.active?)
    redirect_back fallback_location: admin_food_items_path,
                  notice: "#{@food_item.category_label} #{@food_item.active? ? 'activated' : 'deactivated'}."
  end

  def destroy
    if @food_item.order_items.exists?
      redirect_to admin_food_items_path, alert: "Cannot delete — category has existing orders."
    else
      @food_item.destroy!
      redirect_to admin_food_items_path, notice: "Category removed."
    end
  end

  private

  def set_food_item
    @food_item = FoodItem.find(params[:id])
  end

  def ensure_admin!
    redirect_to root_path unless current_user.admin?
  end
end
