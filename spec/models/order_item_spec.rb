require "rails_helper"

RSpec.describe OrderItem, type: :model do
  it "generates unique item_code on create" do
    user = create_user(role: :employee)
    order, = create_order_with_token_for(user: user)
    item = FoodItem.find_by!(category: "lunch")
    order_item = described_class.create!(order: order, food_item: item)

    expect(order_item.item_code).to start_with("FI-")
  end

  it "marks redeemed with vendor user" do
    employee = create_user(role: :employee)
    vendor = create_user(role: :vendor)
    order, = create_order_with_token_for(user: employee)
    order_item = order.order_items.first

    expect(order_item.redeem!(vendor)).to eq(true)
    expect(order_item.reload).to be_redeemed
    expect(order_item.redeemed_by_id).to eq(vendor.id)
  end
end
