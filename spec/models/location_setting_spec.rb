require "rails_helper"

RSpec.describe LocationSetting, type: :model do
  describe ".gps_setting" do
    it "returns a singleton gps_based setting" do
      first = described_class.gps_setting
      second = described_class.gps_setting

      expect(first.id).to eq(second.id)
      expect(first.setting_type).to eq("gps_based")
    end
  end

  describe ".check" do
    it "delegates to Location::Checker" do
      expect(Location::Checker).to receive(:call).with(lat: 12.34, lng: 56.78, setting: described_class.gps_setting).and_return(:allowed)

      result = described_class.check(12.34, 56.78)
      expect(result).to eq(:allowed)
    end
  end
end
