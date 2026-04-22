class CreateOrderItems < ActiveRecord::Migration[8.1]
  def change
    create_table :order_items do |t|
      t.references :order,     null: false, foreign_key: true
      t.references :food_item, null: false, foreign_key: true
      t.datetime :redeemed_at
      t.timestamps
    end

    add_index :order_items, [:order_id, :food_item_id], unique: true
    add_index :order_items, :redeemed_at
  end
end