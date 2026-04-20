require "rails_helper"

RSpec.describe Location::Checker do
  describe ".call" do
    let(:setting) do
      LocationSetting.gps_setting.tap do |record|
        record.update!(
          enabled: true,
          latitude: 22.7196,
          longitude: 75.8577,
          radius_meters: 200
        )
      end
    end

    it "allows access when restriction is disabled" do
      setting.update!(enabled: false)

      result = described_class.call(lat: 10.0, lng: 20.0, setting: setting)
      expect(result).to eq(:allowed)
    end

    it "returns no_location for blank coordinates" do
      result = described_class.call(lat: nil, lng: "", setting: setting)
      expect(result).to eq(:no_location)
    end

    it "returns no_location for invalid coordinate range" do
      result = described_class.call(lat: 120.0, lng: 75.0, setting: setting)
      expect(result).to eq(:no_location)
    end

    it "returns no_location for zero coordinates" do
      result = described_class.call(lat: 0.0, lng: 0.0, setting: setting)
      expect(result).to eq(:no_location)
    end

    it "allows coordinates inside configured radius" do
      result = described_class.call(lat: 22.71961, lng: 75.85771, setting: setting)
      expect(result).to eq(:allowed)
    end

    it "denies coordinates outside configured radius" do
      result = described_class.call(lat: 23.0, lng: 76.0, setting: setting)
      expect(result).to eq(:denied)
    end
  end
end
