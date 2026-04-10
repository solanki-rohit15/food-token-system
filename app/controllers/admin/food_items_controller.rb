class Admin::FoodItemsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin!
  before_action :set_food_item, only: [:show, :edit, :update, :destroy, :toggle_active]

  def index
    @food_items = FoodItem.order(:sort_order, :category)
  end

  def show; end

  def new
    @food_item = FoodItem.new(active: true)
  end

  def create
    @food_item = FoodItem.new(food_item_params)
    if @food_item.save
      redirect_to admin_food_items_path, notice: "Food item added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @food_item.update(food_item_params)
      redirect_to admin_food_items_path, notice: "Food item updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @food_item.order_items.exists?
      redirect_to admin_food_items_path, alert: "Cannot delete — item has existing orders."
    else
      @food_item.destroy
      redirect_to admin_food_items_path, notice: "Food item deleted."
    end
  end

  def toggle_active
    @food_item.update!(active: !@food_item.active?)
    status = @food_item.active? ? "activated" : "deactivated"
    redirect_back fallback_location: admin_food_items_path, notice: "Food item #{status}."
  end

  private

  def set_food_item
    @food_item = FoodItem.find(params[:id])
  end

  def food_item_params
    params.require(:food_item).permit(:category, :active, :sort_order)
  end

  def ensure_admin!
    redirect_to root_path unless current_user.admin?
  end
end