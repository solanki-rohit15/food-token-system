class AddPriceToMealSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :meal_settings, :price, :decimal, precision: 10, scale: 2, default: 0, null: false
  end
end
