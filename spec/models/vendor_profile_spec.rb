require "rails_helper"

RSpec.describe VendorProfile, type: :model do
  it "auto-generates vendor_id on create" do
    user = create_user(role: :vendor)
    expect(user.vendor_profile.vendor_id).to start_with("VND")
  end

  it "requires stall_name" do
    user = create_user(role: :vendor)
    profile = described_class.new(user: user, vendor_id: "VND9999", stall_name: nil)
    expect(profile).not_to be_valid
  end
end
