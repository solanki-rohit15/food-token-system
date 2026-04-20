# Idempotent seeds — safe to run multiple times

puts "🌱 Seeding database..."

# ── Admin ──────────────────────────────────────────────────────────
admin = User.find_or_create_by!(email: "admin@company.com") do |u|
  u.name                = "System Admin"
  u.password            = "Admin@1234"
  u.role                = :admin
  u.active              = true
  u.admin_created       = true
  u.confirmed_at        = Time.current
  u.must_change_password = false
end
puts "✅ Admin: admin@company.com / Admin@1234"

# ── Vendor ────────────────────────────────────────────────────────
vendor = User.find_or_create_by!(email: "vendor@company.com") do |u|
  u.name                = "Cafeteria Vendor"
  u.password            = "Vendor@1234"
  u.role                = :vendor
  u.active              = true
  u.admin_created       = true
  u.confirmed_at        = Time.current
  u.must_change_password = false
end
vendor.create_vendor_profile!(stall_name: "Main Cafeteria", vendor_id: "VND0001") unless vendor.vendor_profile
puts "✅ Vendor: vendor@company.com / Vendor@1234"

# ── Employees ─────────────────────────────────────────────────────
departments = %w[Engineering Design HR Finance Sales Operations]
[
  { name: "Alice Smith",  email: "employee1@company.com" },
  { name: "Bob Johnson",  email: "employee2@company.com" },
  { name: "Carol Davis",  email: "employee3@company.com" },
  { name: "David Lee",    email: "employee4@company.com" },
  { name: "Emma Wilson",  email: "employee5@company.com" }
].each_with_index do |attrs, i|
  emp = User.find_or_create_by!(email: attrs[:email]) do |u|
    u.name                = attrs[:name]
    u.password            = "Employee@123"
    u.role                = :employee
    u.active              = true
    u.admin_created       = true
    u.confirmed_at        = Time.current
    u.must_change_password = false
  end
  unless emp.employee_profile
    emp.create_employee_profile!(
      employee_id: "EMP#{(i + 1).to_s.rjust(4, '0')}",
      department:  departments[i]
    )
  end
  puts "✅ Employee: #{attrs[:email]} / Employee@123"
end

# ── Food Items (one per category) ─────────────────────────────────
FoodItem::CATEGORIES.each_with_index do |(cat, _), i|
  FoodItem.find_or_create_by!(category: cat) do |fi|
    fi.active     = true
    fi.sort_order = i
  end
  puts "✅ FoodItem: #{cat}"
end

# ── Meal Settings with prices ─────────────────────────────────────
MealSetting::MEAL_TYPES.each do |mt|
  s = MealSetting.find_or_initialize_for(mt)
  s.save! if s.new_record?
  puts "✅ MealSetting: #{mt} | #{s.start_time}–#{s.end_time} | ₹#{s.price}"
end

puts "\n🎉 Seeds complete!"
puts "Admin:    admin@company.com    / Admin@1234"
puts "Vendor:   vendor@company.com   / Vendor@1234"
puts "Employee: employee1@company.com / Employee@123"
