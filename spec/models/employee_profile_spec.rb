require "rails_helper"

RSpec.describe EmployeeProfile, type: :model do
  it "auto-generates employee_id on create" do
    user = create_user(role: :employee)
    profile = user.employee_profile
    expect(profile.employee_id).to start_with("EMP")
  end

  it "requires department" do
    user = create_user(role: :employee)
    profile = described_class.new(user: user, employee_id: "EMP99999", department: nil)
    expect(profile).not_to be_valid
  end
end
