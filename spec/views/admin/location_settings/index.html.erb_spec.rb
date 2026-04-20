require "rails_helper"

RSpec.describe "admin/location_settings/index.html.erb", type: :view do
  before do
    assign(:setting, LocationSetting.gps_setting)
  end

  it "renders location settings form controls" do
    render
    expect(rendered).to include("GPS Location Settings")
    expect(rendered).to include("location_setting[latitude]")
    expect(rendered).to include("location_setting[longitude]")
  end
end
