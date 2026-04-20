require "rails_helper"

RSpec.describe "Vendor controllers", type: :request do
  let(:vendor) { create_user(role: :vendor) }
  let(:employee) { create_user(role: :employee) }

  before do
    create_meal_settings
    create_food_items
  end

  it "requires login for vendor pages" do
    get vendor_root_path
    expect(response).to redirect_to(new_user_session_path)
  end

  context "signed in vendor" do
    before { sign_in vendor }

    it "renders dashboard/tokens/scanner/employees pages" do
      get vendor_root_path
      expect(response).to have_http_status(:ok)
      get vendor_tokens_path
      expect(response).to have_http_status(:ok)
      get vendor_scan_path
      expect(response).to have_http_status(:ok)
      get vendor_employees_path
      expect(response).to have_http_status(:ok)
    end

    it "verifies scanner payload with missing qr_data as unprocessable" do
      post vendor_verify_scan_path, params: { qr_data: "" }, as: :json
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "verifies scanner payload successfully for token qr data" do
      _, token = create_order_with_token_for(user: employee, categories: ["lunch"])
      post vendor_verify_scan_path, params: { qr_data: token.qr_payload }, as: :json

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["valid"]).to eq(true)
      expect(body["token_id"]).to eq(token.id)
      expect(body["items"]).to be_an(Array)
    end

    it "returns unprocessable for expired token in scanner verify" do
      _, token = create_order_with_token_for(user: employee, categories: ["lunch"])
      token.update!(expires_at: 1.minute.ago)

      post vendor_verify_scan_path, params: { qr_data: token.qr_payload }, as: :json
      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)["valid"]).to eq(false)
    end

    it "sends redemption request for valid order_item" do
      _, token = create_order_with_token_for(user: employee, categories: ["lunch"])
      order_item = token.order.order_items.first

      post send_redemption_request_vendor_token_path(token), params: { order_item_id: order_item.id }, as: :json
      expect(response).to have_http_status(:ok)
      expect(RedemptionRequest.where(token: token, order_item: order_item, vendor: vendor).exists?).to eq(true)
    end

    it "returns unprocessable when token is not redeemable" do
      _, token = create_order_with_token_for(user: employee, categories: ["lunch"])
      token.update!(status: :expired)
      order_item = token.order.order_items.first

      post send_redemption_request_vendor_token_path(token), params: { order_item_id: order_item.id }, as: :json
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns unprocessable when pending request already exists for item" do
      _, token = create_order_with_token_for(user: employee, categories: ["lunch"])
      order_item = token.order.order_items.first
      RedemptionRequest.create!(token: token, order_item: order_item, vendor: vendor, status: :pending)

      post send_redemption_request_vendor_token_path(token), params: { order_item_id: order_item.id }, as: :json
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns not_found for wrong order_item in redemption request" do
      _, token = create_order_with_token_for(user: employee, categories: ["lunch"])

      post send_redemption_request_vendor_token_path(token), params: { order_item_id: 999_999 }, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end
end
