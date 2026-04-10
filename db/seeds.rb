# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# ── Admin ──────────────────────────────────────────────────
admin = User.find_or_create_by!(email: "admin@company.com") do |u|
  u.name       = "System Admin"
  u.password   = "Admin@1234"
  u.role       = :admin
  u.active     = true
  u.confirmed_at = Time.current
end
puts "✅ Admin: admin@company.com / Admin@1234"

# ── Vendor ─────────────────────────────────────────────────
vendor = User.find_or_create_by!(email: "vendor@company.com") do |u|
  u.name       = "Cafeteria Vendor"
  u.password   = "Vendor@1234"
  u.role       = :vendor
  u.active     = true
  u.confirmed_at = Time.current
end
vendor.create_vendor_profile!(stall_name: "Main Cafeteria", vendor_id: "VND0001") unless vendor.vendor_profile
puts "✅ Vendor: vendor@company.com / Vendor@1234"
# ── Employees ──────────────────────────────────────────────
departments = ["Engineering", "Design", "HR", "Finance", "Sales", "Operations"]

5.times do |i|
  emp = User.find_or_create_by!(email: "employee#{i+1}@company.com") do |u|
    u.name         = ["Alice Smith", "Bob Johnson", "Carol Davis", "David Lee", "Emma Wilson"][i]
    u.password     = "Employee@123"
    u.role         = :employee
    u.active       = true
    u.confirmed_at = Time.current
  end

  unless emp.employee_profile
    emp.create_employee_profile!(
      employee_id: "EMP#{(i+1).to_s.rjust(4,'0')}",
      department:  departments[i]
    )
  end

  puts "✅ Employee: employee#{i+1}@company.com / Employee@123"
end

# ── Food Items ─────────────────────────────────────────────
food_data = [
  { name: "Tea",           category: "morning_tea", description: "Masala / Plain Tea" },
  { name: "Coffee",        category: "morning_tea", description: "Filter / Instant Coffee" },
  { name: "Idli Sambar",   category: "breakfast",   description: "Soft idlis with fresh sambar" },
  { name: "Poha",          category: "breakfast",   description: "Flattened rice with veggies" },
  { name: "Veg Thali",     category: "lunch",       description: "Rice, Dal, 2 Sabzi, Roti, Salad" },
  { name: "Egg Rice",      category: "lunch",       description: "Fried rice with egg" },
  { name: "Sandwich",      category: "lunch",       description: "Veg / Egg club sandwich" },
  { name: "Evening Tea",   category: "evening_tea", description: "Tea / Coffee with snacks" },
  { name: "Samosa",        category: "evening_tea", description: "Crispy potato samosas" },
]

food_data.each_with_index do |fd, i|
  fi = FoodItem.find_or_create_by!(name: fd[:name], category: fd[:category]) do |f|
    f.description = fd[:description]
    f.active      = true
    f.sort_order  = i
  end
  puts "✅ FoodItem: #{fi.name} (#{fi.category})"
end

# ── Meal Settings ──────────────────────────────────────────
MealSetting::MEAL_TYPES.each do |mt|
  s = MealSetting.find_or_initialize_for(mt)
  s.save! if s.new_record?
  puts "✅ MealSetting: #{mt}"
end

puts "\n🎉 Seeds complete!"
puts "Admin:    admin@company.com    / Admin@1234"
puts "Vendor:   vendor@company.com   / Vendor@1234"
puts "Employee: employee1@company.com / Employee@123"
