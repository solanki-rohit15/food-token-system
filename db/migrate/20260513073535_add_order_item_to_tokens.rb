class AddOrderItemToTokens < ActiveRecord::Migration[8.1]
  def change
    add_reference :tokens, :order_item, null: true, foreign_key: true
  end
end
