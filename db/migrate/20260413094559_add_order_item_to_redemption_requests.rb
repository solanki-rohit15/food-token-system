class AddOrderItemToRedemptionRequests < ActiveRecord::Migration[8.1]
  def change
add_reference :redemption_requests, :order_item, foreign_key: true
  end
end
