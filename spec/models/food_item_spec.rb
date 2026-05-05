require "rails_helper"


RSpec.describe FoodItem, type: :model do
  describe "validations" do
    it "rejects invalid category" do
      item = build(:food_item, category: "invalid")
      expect(item).not_to be_valid
    end

    it "rejects duplicate category" do
      create(:food_item, category: "breakfast")
      duplicate = build(:food_item, category: "breakfast")
      expect(duplicate).not_to be_valid
    end

    it "accepts valid category" do
      item = build(:food_item, category: "lunch")
      expect(item).to be_valid
    end
  end



  describe "#available_now?" do
    it "returns false when inactive" do
      item = create(:food_item, active: false)
      expect(item.available_now?).to be false
    end
  end

  describe "#category helpers" do
    it "returns icon and label" do
      item = create(:food_item, category: "lunch")
      expect(item.icon).to be_present
      expect(item.category_label).to eq("Lunch")
    end
  end
end
