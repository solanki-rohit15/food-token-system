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


puts "\n🎉 Seeds complete!"
puts "Admin:    admin@company.com    / Admin@1234"
puts "Vendor:   vendor@company.com   / Vendor@1234"


MealSetting::MEAL_TYPES.each do |meal_type|
  data = {
    "morning_tea" => { start_time: "08:00", end_time: "11:00", price: 20 },
    "breakfast"   => { start_time: "08:30", end_time: "11:00", price: 30 },
    "lunch"       => { start_time: "12:00", end_time: "14:30", price: 120 },
    "evening_tea" => { start_time: "15:30", end_time: "18:00", price: 20 }
  }[meal_type]

  MealSetting.find_or_create_by!(meal_type: meal_type) do |s|
    s.start_time = Time.zone.parse(data[:start_time])
    s.end_time   = Time.zone.parse(data[:end_time])
    s.price      = data[:price]
  end
end
