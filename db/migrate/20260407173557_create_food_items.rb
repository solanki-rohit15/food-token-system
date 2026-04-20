class CreateFoodItems < ActiveRecord::Migration[8.1]
  def change
    create_table :food_items do |t|
      t.string  :category,    null: false
      t.boolean :active,      default: true
      t.integer :sort_order,  default: 0
      t.timestamps
    end
    add_index :food_items, :category
    add_index :food_items, :active
  end
end
