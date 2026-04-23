source "https://rubygems.org"

gem "rails",          "~> 8.1.3"                         # Modern asset pipeline
gem "pg",             "~> 1.1"          # PostgreSQL
gem "puma",           ">= 5.0"          # Web server

gem "image_processing", "~> 1.2"

# Hotwire / Turbo

gem "turbo-rails"
gem "stimulus-rails"

# Authentication
gem "devise"
gem "omniauth-google-oauth2"
gem "omniauth-rails_csrf_protection"

# Authorization
gem "pundit", "~> 2.3"

# QR Code generation (SVG — no chunky_png needed)
gem "rqrcode"

# Pagination
gem "kaminari", "~> 1.2"

# CSS framework (SCSS)
gem "bootstrap",         "~> 5.3"
gem "sassc-rails"
gem "font-awesome-sass", "~> 6.5"

# Background jobs — solid_queue handles Active Job, no sidekiq/redis needed
gem "solid_queue"
gem "solid_cache"
gem "solid_cable"

# Env vars
gem "dotenv-rails", "~> 3.2"

# Mailer OAuth SSL fix
gem "faraday",          "~> 2.9"
gem "faraday-net_http", "~> 3.4"

gem "tzinfo-data", platforms: %i[windows jruby]
gem "bootsnap", require: false
gem "kamal",    require: false
gem "thruster", require: false

group :development, :test do
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "brakeman",      require: false
  gem "rubocop-rails-omakase", require: false
end

group :development do
  gem "web-console"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end

gem "jquery-rails"
gem "geocoder"

group :development, :test do
  gem "rspec-rails"
  gem "factory_bot_rails"  
end