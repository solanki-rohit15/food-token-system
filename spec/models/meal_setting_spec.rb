require "rails_helper"

RSpec.describe MealSetting, type: :model do
  describe ".find_or_initialize_for" do
    it "initializes with default values for known meal type" do
      setting = described_class.find_or_initialize_for("breakfast")
      expect(setting.meal_type).to eq("breakfast")
      expect(setting.start_time).to be_present
      expect(setting.end_time).to be_present
      expect(setting.price).to be >= 0
    end
  end

  describe "#formatted_time_range" do
    it "returns formatted range when times exist" do
      setting = MealSetting.create!(
        meal_type: "lunch",
        start_time: Time.zone.parse("12:00"),
        end_time: Time.zone.parse("14:00"),
        price: 100
      )
      expect(setting.formatted_time_range).to include("12:00")
    end
  end
end
