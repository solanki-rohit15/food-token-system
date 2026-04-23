ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.
# config/boot.rb  (add at the bottom)
if ENV["RAILS_ENV"] == "production" &&
   ENV["SECRET_KEY_BASE"].blank? &&
   ENV["RAILS_MASTER_KEY"].blank?

  ENV["SECRET_KEY_BASE"] = "0" * 128   # valid 64-byte dummy
end