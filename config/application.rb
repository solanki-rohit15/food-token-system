require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)

module FoodTokenSystem
  class Application < Rails::Application
    config.load_defaults 8.1

    config.autoload_lib(ignore: %w[assets tasks])

    config.time_zone = "Asia/Kolkata"
    config.active_record.default_timezone = :local

    # ── Secret key: prefer ENV var, fall back to credentials ──────────
    # This lets Render build work without RAILS_MASTER_KEY.
    # Set SECRET_KEY_BASE in Render Dashboard → Environment Variables.
    config.secret_key_base = ENV["SECRET_KEY_BASE"] if ENV["SECRET_KEY_BASE"].present?
  end
end
