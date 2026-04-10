class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :food_item

  validates :order_id, uniqueness: { scope: :food_item_id, message: "already has this item" }
end
