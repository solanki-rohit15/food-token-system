module TestDataHelper
  def create_user(role:, active: true, must_change_password: false, confirmed_at: Time.current)
    user = User.create!(
      name: "#{role.to_s.capitalize} User #{SecureRandom.hex(3)}",
      email: "#{role}-#{SecureRandom.hex(4)}@example.com",
      password: "Password@123",
      password_confirmation: "Password@123",
      role: role,
      active: active,
      confirmed_at: confirmed_at,
      must_change_password: must_change_password
    )

    if role.to_sym == :employee
      EmployeeProfile.create!(user: user, department: "Engineering")
    elsif role.to_sym == :vendor
      VendorProfile.create!(user: user, stall_name: "Main Stall")
    end

    user
  end

  def create_food_items
    FoodItem::CATEGORIES.keys.each_with_index.map do |category, idx|
      FoodItem.find_or_create_by!(category: category) do |item|
        item.active = true
        item.sort_order = idx
      end
    end
  end

  def create_meal_settings
    MealSetting.defaults.each do |meal_type, attrs|
      MealSetting.find_or_create_by!(meal_type: meal_type) do |setting|
        setting.start_time = Time.zone.parse(attrs[:start_time])
        setting.end_time = Time.zone.parse(attrs[:end_time])
        setting.price = attrs[:price]
      end
    end
  end

  def create_order_with_token_for(user:, categories: [ "breakfast" ])
    create_food_items
    order = Order.create!(user: user, date: Date.current)
    categories.each do |cat|
      item = FoodItem.find_by!(category: cat)
      OrderItem.create!(order: order, food_item: item)
    end
    token = order.generate_token!
    token.update!(expires_at: 2.hours.from_now, status: :active)
    [ order, token ]
  end
end

RSpec.configure do |config|
  config.include TestDataHelper
end
