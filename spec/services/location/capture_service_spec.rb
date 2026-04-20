require "rails_helper"

RSpec.describe Location::CaptureService do
  describe "#call" do
    let(:session) { {} }
    let(:service) { described_class.new(session: session) }
    let(:setting) { LocationSetting.gps_setting }

    before do
      setting.update!(enabled: true, latitude: 22.7196, longitude: 75.8577, radius_meters: 200)
    end

    it "stores rounded coordinates and returns allowed response" do
      result = service.call(latitude: "22.719611", longitude: "75.857711")

      expect(result.success).to eq(true)
      expect(result.allowed).to eq(true)
      expect(result.status).to eq(:allowed)
      expect(session[:user_lat]).to eq(22.719611)
      expect(session[:user_lng]).to eq(75.857711)
      expect(session[:location_at]).to be_present
    end

    it "returns denied with success true for outside zone" do
      result = service.call(latitude: "23.5", longitude: "76.5")

      expect(result.success).to eq(true)
      expect(result.allowed).to eq(false)
      expect(result.status).to eq(:denied)
    end

    it "returns no_location when permission denied and restriction enabled" do
      result = service.call(latitude: nil, longitude: nil)

      expect(result.success).to eq(true)
      expect(result.allowed).to eq(false)
      expect(result.status).to eq(:no_location)
      expect(result.message).to eq("Location permission denied.")
      expect(session[:user_lat]).to be_nil
      expect(session[:user_lng]).to be_nil
      expect(session[:location_at]).to be_present
    end

    it "returns invalid coordinate response for 0,0" do
      result = service.call(latitude: "0", longitude: "0")

      expect(result.success).to eq(false)
      expect(result.allowed).to eq(false)
      expect(result.http_status).to eq(:unprocessable_content)
      expect(result.message).to eq("Invalid coordinates.")
      expect(session[:location_at]).to eq(0)
    end
  end
end
