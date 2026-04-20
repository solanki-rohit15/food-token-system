require "rails_helper"

RSpec.describe "User flows", type: :request do
  let(:employee) { create_user(role: :employee) }

  describe "pages/home" do
    it "renders home for guest" do
      get root_path
      expect(response).to have_http_status(:ok)
    end

    it "redirects signed in user to dashboard" do
      sign_in employee
      get root_path
      expect(response).to redirect_to(employee_root_path)
    end
  end

  describe "registration and recoverable flows" do
    it "disables public sign up routes" do
      get "/users/sign_up"
      expect(response).to have_http_status(:not_found)
    end

    it "shows generic success for forgot password even when email does not exist" do
      post user_password_path, params: { user: { email: "missing@example.com" } }
      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:notice]).to include("If your email address exists")
    end

    it "shows generic success for forgot password when email exists" do
      post user_password_path, params: { user: { email: employee.email } }
      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:notice]).to include("If your email address exists")
    end
  end

  describe "change password" do
    before { sign_in employee }

    it "rejects short password" do
      patch users_change_password_path, params: { password: "short", password_confirmation: "short" }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects mismatched confirmation" do
      patch users_change_password_path, params: { password: "Password@123", password_confirmation: "Password@124" }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "session destroy" do
    it "clears gps session keys on logout" do
      sign_in employee
      delete destroy_user_session_path
      expect(response).to redirect_to(root_path)
      expect(session[:user_lat]).to be_nil
      expect(session[:user_lng]).to be_nil
      expect(session[:location_at]).to be_nil
    end
  end
end
