require "rails_helper"

RSpec.describe "Employee::LocationController", type: :request do
  let(:employee) do
    User.create!(
      name: "Employee User",
      email: "employee@example.com",
      password: "Password@123",
      password_confirmation: "Password@123",
      role: :employee,
      confirmed_at: Time.current
    )
  end

  before do
    LocationSetting.gps_setting.update!(
      enabled: true,
      latitude: 22.7196,
      longitude: 75.8577,
      radius_meters: 200
    )
    sign_in employee
  end

  describe "POST /employee/location" do
    it "returns allowed payload when coordinates are valid and in range" do
      post employee_update_location_path, params: { latitude: 22.71961, longitude: 75.85771 }, as: :json

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["success"]).to eq(true)
      expect(body["allowed"]).to eq(true)
      expect(body["status"]).to eq("allowed")
    end

    it "returns unprocessable_content when invalid coordinates are sent" do
      post employee_update_location_path, params: { latitude: 0, longitude: 0 }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      body = JSON.parse(response.body)
      expect(body["success"]).to eq(false)
      expect(body["allowed"]).to eq(false)
    end

    it "returns no_location when location permission is denied" do
      post employee_update_location_path, params: {}, as: :json

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["success"]).to eq(true)
      expect(body["status"]).to eq("no_location")
    end
  end
end
