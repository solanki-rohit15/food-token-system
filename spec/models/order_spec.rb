require "rails_helper"

RSpec.describe Order, type: :model do
  describe "validations" do
    it "enforces one order per user per date" do
      user = create_user(role: :employee)
      described_class.create!(user: user, date: Date.current)
      duplicate = described_class.new(user: user, date: Date.current)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to be_present
    end
  end

  describe "#generate_token!" do
    it "creates and memoizes a token" do
      user = create_user(role: :employee)
      order = described_class.create!(user: user, date: Date.current)

      first = order.generate_token!
      second = order.generate_token!
      expect(first.id).to eq(second.id)
    end
  end
end
