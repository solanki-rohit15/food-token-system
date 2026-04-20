require "rails_helper"

RSpec.describe "Employee controllers", type: :request do
  let(:employee) { create_user(role: :employee) }
  let(:vendor) { create_user(role: :vendor) }

  before do
    LocationSetting.gps_setting.update!(enabled: false)
    create_meal_settings
    create_food_items
  end

  it "requires login for employee dashboard" do
    get employee_root_path
    expect(response).to redirect_to(new_user_session_path)
  end

  context "signed in employee" do
    before { sign_in employee }

    it "renders dashboard and tokens index" do
      get employee_root_path
      expect(response).to have_http_status(:ok)
      get employee_tokens_path
      expect(response).to have_http_status(:ok)
    end

    it "rejects food selection create without categories" do
      post employee_food_selections_path, params: { categories: [] }
      expect(response).to redirect_to(new_employee_food_selection_path)
    end

    it "creates order and token for valid categories" do
      MealSetting.find_or_initialize_for("breakfast").tap do |setting|
        setting.start_time = 1.hour.ago
        setting.end_time = 1.hour.from_now
        setting.price = 20
        setting.save!
      end

      post employee_food_selections_path, params: { categories: ["breakfast"] }
      token = Token.joins(:order).where(orders: { user_id: employee.id }).last
      expect(token).to be_present
      expect(response).to redirect_to(employee_token_path(token))
    end

    it "returns token status json" do
      _, token = create_order_with_token_for(user: employee, categories: ["lunch"])
      get status_employee_token_path(token), as: :json
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["token_status"]).to be_present
    end

    it "redirects when employee requests token they do not own" do
      other_employee = create_user(role: :employee)
      _, other_token = create_order_with_token_for(user: other_employee, categories: ["lunch"])

      get employee_token_path(other_token)
      expect(response).to redirect_to(employee_tokens_path)
    end

    it "approves and rejects redemption requests" do
      _, token = create_order_with_token_for(user: employee, categories: ["lunch"])
      req = RedemptionRequest.create!(token: token, order_item: token.order.order_items.first, vendor: vendor, status: :pending)

      post approve_employee_redemption_request_path(req), as: :json
      expect(response).to have_http_status(:ok)
      expect(req.reload).to be_approved

      req2 = RedemptionRequest.create!(token: token, order_item: token.order.order_items.last || token.order.order_items.first, vendor: vendor, status: :pending)
      post reject_employee_redemption_request_path(req2), as: :json
      expect(response).to have_http_status(:ok)
      expect(req2.reload).to be_rejected
    end

    it "returns not found for redemption request not owned by employee" do
      other_employee = create_user(role: :employee)
      _, token = create_order_with_token_for(user: other_employee, categories: ["lunch"])
      req = RedemptionRequest.create!(token: token, order_item: token.order.order_items.first, vendor: vendor, status: :pending)

      post approve_employee_redemption_request_path(req), as: :json
      expect(response).to have_http_status(:not_found)
    end
  end
end
