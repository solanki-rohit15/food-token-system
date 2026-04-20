require "rails_helper"

RSpec.describe Token, type: :model do
  it "creates token_number automatically" do
    user = create_user(role: :employee)
    _, token = create_order_with_token_for(user: user)
    expect(token.token_number).to start_with("FT-")
  end

  it "parses qr payload to find token" do
    user = create_user(role: :employee)
    _, token = create_order_with_token_for(user: user)
    found = described_class.find_by_qr(token.qr_payload)
    expect(found).to eq(token)
  end

  it "is not redeemable when expired by time" do
    user = create_user(role: :employee)
    _, token = create_order_with_token_for(user: user)
    token.update!(expires_at: 1.hour.ago)
    expect(token.redeemable?).to eq(false)
  end
end
