require "rails_helper"

RSpec.describe "pages/home.html.erb", type: :view do
  it "renders product name on home page" do
    render
    expect(rendered).to include("Food")
  end
end
