#!/usr/bin/env ruby

# Location System Verification Script
# Run this to verify all components are properly set up
#
# Usage: 
#   cd /Users/abc/Desktop/rails-project/food-token-system
#   ruby script/verify_location_system.rb

puts "🔍 Location System Verification"
puts "=" * 60

checks_passed = 0
checks_failed = 0

def check(description)
  print "#{description}... "
  result = yield
  if result
    puts "✅"
    true
  else
    puts "❌"
    false
  end
end

def check_file_contains(file_path, content, description = nil)
  description ||= "#{File.basename(file_path)} contains required code"
  check(description) do
    File.exist?(file_path) && File.read(file_path).include?(content)
  end
end

# 1. Check location.js import in application.js (not in importmap)
if check_file_contains(
  "app/javascript/application.js",
  'import "./location.js"',
  "1. application.js imports location.js with direct relative path"
)
  checks_passed += 1
else
  checks_failed += 1
end

# 2. Check LocationValidator service exists
if File.exist?("app/services/location_validator.rb")
  if check_file_contains(
    "app/services/location_validator.rb",
    "def self.validate_login",
    "2. LocationValidator service exists with validate_login"
  )
    checks_passed += 1
  else
    checks_failed += 1
  end
else
  puts "2. LocationValidator service exists... ❌"
  checks_failed += 1
end

# 3. Check ApplicationController has check_location_access
if check_file_contains(
  "app/controllers/application_controller.rb",
  "LocationValidator",
  "3. ApplicationController uses LocationValidator"
)
  checks_passed += 1
else
  checks_failed += 1
end

# 4. Check SessionsController validates location
if check_file_contains(
  "app/controllers/users/sessions_controller.rb",
  "validate_employee_location",
  "4. SessionsController validates location at login"
)
  checks_passed += 1
else
  checks_failed += 1
end

# 5. Check location.js is in app/javascript
if File.exist?("app/javascript/location.js")
  if check_file_contains(
    "app/javascript/location.js",
    "initLocationTracking",
    "5. location.js exists with initLocationTracking"
  )
    checks_passed += 1
  else
    checks_failed += 1
  end
else
  puts "5. location.js exists... ❌"
  checks_failed += 1
end

# 6. Check location.js is in app/javascript
if check_file_contains(
  "app/javascript/location.js",
  "function initLocationTracking",
  "6. location.js exists with proper function definitions"
)
  checks_passed += 1
else
  checks_failed += 1
end

# 7. Check application layout has meta tag
if check_file_contains(
  "app/views/layouts/application.html.erb",
  'name="current-user-role"',
  "7. application.html.erb has current-user-role meta tag"
)
  checks_passed += 1
else
  checks_failed += 1
end

# 8. Check Employee LocationController updated
if check_file_contains(
  "app/controllers/employee/location_controller.rb",
  "session[:location_at]",
  "8. Employee LocationController stores location timestamp"
)
  checks_passed += 1
else
  checks_failed += 1
end

# 9. Check LocationSetting uses validator
if check_file_contains(
  "app/models/location_setting.rb",
  "LocationValidator",
  "9. LocationSetting delegates to LocationValidator"
)
  checks_passed += 1
else
  checks_failed += 1
end

puts "=" * 60
puts "Results: #{checks_passed} passed, #{checks_failed} failed"

if checks_failed == 0
  puts "\n✅ All checks passed! Location system is properly configured."
  exit 0
else
  puts "\n❌ Some checks failed. Review the LOCATION_SECURITY_GUIDE.md"
  exit 1
end
