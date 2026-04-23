ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup"
require "bootsnap/setup"

# Render deployment: ensure secret_key_base is available before any gem loads.
# Uses plain Ruby .nil? and .empty? — NOT .blank? (that's ActiveSupport, not loaded yet).
if ENV["RAILS_ENV"] == "production" &&
   (ENV["SECRET_KEY_BASE"].nil? || ENV["SECRET_KEY_BASE"].empty?) &&
   (ENV["RAILS_MASTER_KEY"].nil? || ENV["RAILS_MASTER_KEY"].empty?)
  ENV["SECRET_KEY_BASE"] = "0" * 128
end