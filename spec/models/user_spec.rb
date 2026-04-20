require "rails_helper"

RSpec.describe User, type: :model do
  describe "validations" do
    it "requires name, email, role" do
      user = User.new
      expect(user).not_to be_valid
      expect(user.errors[:name]).to be_present
      expect(user.errors[:email]).to be_present
    end
  end

  describe "#dashboard_path" do
    it "returns role specific dashboard paths" do
      expect(create_user(role: :admin).dashboard_path).to eq(Rails.application.routes.url_helpers.admin_root_path)
      expect(create_user(role: :vendor).dashboard_path).to eq(Rails.application.routes.url_helpers.vendor_root_path)
      expect(create_user(role: :employee).dashboard_path).to eq(Rails.application.routes.url_helpers.employee_root_path)
    end
  end

  describe "#initials" do
    it "returns up to two initials" do
      user = create_user(role: :employee)
      user.update!(name: "John Doe")
      expect(user.initials).to eq("JD")
    end
  end
end
