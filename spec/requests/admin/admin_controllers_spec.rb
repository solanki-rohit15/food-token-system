require "rails_helper"

RSpec.describe "Admin controllers", type: :request do
  let(:admin) { create_user(role: :admin) }
  let(:employee) { create_user(role: :employee) }

  before do
    create_meal_settings
    create_food_items
  end

  context "authentication and authorization" do
    it "redirects guest from admin dashboard" do
      get admin_root_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "blocks non-admin user" do
      sign_in employee
      get admin_root_path
      expect(response).to redirect_to(root_path)
    end
  end

  context "admin actions" do
    before { sign_in admin }

    it "renders key index pages" do
      get admin_root_path
      expect(response).to have_http_status(:ok)
      get admin_users_path
      expect(response).to have_http_status(:ok)
      get admin_food_items_path
      expect(response).to have_http_status(:ok)
      get admin_meal_settings_path
      expect(response).to have_http_status(:ok)
      get admin_location_settings_path
      expect(response).to have_http_status(:ok)
      get admin_tokens_path
      expect(response).to have_http_status(:ok)
      get admin_reports_path
      expect(response).to have_http_status(:ok)
    end

    it "updates location settings with invalid payload as unprocessable" do
      patch admin_location_settings_path, params: {
        location_setting: { enabled: "1", latitude: "", longitude: "", radius_meters: "" }
      }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "creates and toggles user active status" do
      post admin_users_path, params: {
        user: { name: "Emp New", email: "emp-new@example.com", role: "employee", phone: "9999999999", active: true }
      }
      expect(response).to redirect_to(admin_users_path)
      created = User.find_by(email: "emp-new@example.com")
      expect(created).to be_present

      patch toggle_active_admin_user_path(created)
      expect(response).to redirect_to(admin_users_path)
      expect(created.reload.active).to eq(false)
    end

    it "renders report variants and csv export" do
      employee_user = create_user(role: :employee)
      create_order_with_token_for(user: employee_user, categories: [ "breakfast" ])

      get daily_admin_reports_path, params: { date: Date.current.to_s }
      expect(response).to have_http_status(:ok)

      get monthly_admin_reports_path, params: { month: Date.current.strftime("%Y-%m-%d") }
      expect(response).to have_http_status(:ok)

      get employee_wise_admin_reports_path, params: { date: Date.current.to_s }
      expect(response).to have_http_status(:ok)

      get export_admin_reports_path, params: { date: Date.current.to_s }
      expect(response).to have_http_status(:ok)
      expect(response.headers["Content-Type"]).to include("text/csv")
      expect(response.body).to include("Token Number")
    end

    it "handles invalid date gracefully in admin tokens index" do
      get admin_tokens_path, params: { date: "not-a-date", status: "active", search: "abc" }
      expect(response).to have_http_status(:ok)
    end
  end
end
