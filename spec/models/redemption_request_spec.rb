require "rails_helper"

RSpec.describe RedemptionRequest, type: :model do
  it "allows only one pending request per order_item" do
    employee = create_user(role: :employee)
    vendor = create_user(role: :vendor)
    _, token = create_order_with_token_for(user: employee)
    order_item = token.order.order_items.first

    described_class.create!(token: token, order_item: order_item, vendor: vendor, status: :pending)
    duplicate = described_class.new(token: token, order_item: order_item, vendor: vendor, status: :pending)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors.full_messages.join).to include("already pending")
  end

  it "approves and redeems only associated order item" do
    employee = create_user(role: :employee)
    vendor = create_user(role: :vendor)
    _, token = create_order_with_token_for(user: employee, categories: %w[breakfast lunch])
    req = described_class.create!(token: token, order_item: token.order.order_items.first, vendor: vendor, status: :pending)

    expect(req.approve!).to eq(true)
    expect(req.reload).to be_approved
  end
end
