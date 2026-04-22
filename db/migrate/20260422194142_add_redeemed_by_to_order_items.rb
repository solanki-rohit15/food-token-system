class AddRedeemedByToOrderItems < ActiveRecord::Migration[8.1]
  def change
    add_column :order_items, :redeemed_by_id, :integer
  end
end
