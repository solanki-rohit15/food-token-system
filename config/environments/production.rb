require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Code is not reloaded between requests
  config.enable_reloading = false
  config.eager_load = true

  # Full error reports are disabled
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  # Serve static files
  config.public_file_server.enabled = true
  config.public_file_server.headers = {
    "Cache-Control" => "public, max-age=#{1.year.to_i}"
  }

  # Assets
  config.assets.compile = false

  # Active Storage (TEMP: local — use S3 later)
  config.active_storage.service = :local

  # Force SSL (Render supports HTTPS)
  config.force_ssl = true

  # Logging
  config.log_tags = [:request_id]
  config.logger = ActiveSupport::TaggedLogging.logger(STDOUT)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Health check endpoint
  config.silence_healthcheck_path = "/up"

  # Disable deprecation logs
  config.active_support.report_deprecations = false

  # Cache (simple & safe)
  config.cache_store = :memory_store

  # Background jobs (safe default)
  config.active_job.queue_adapter = :async

  # Action Mailer
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.perform_caching = false

  config.action_mailer.default_url_options = {
    host: ENV["APP_HOST"],
    protocol: "https"
  }

  config.action_mailer.delivery_method = :smtp

  config.action_mailer.smtp_settings = {
    address:              ENV["SMTP_HOST"],
    port:                 ENV["SMTP_PORT"].to_i,
    domain:               ENV["SMTP_DOMAIN"],
    user_name:            ENV["SMTP_USER"],
    password:             ENV["SMTP_PASSWORD"],
    authentication:       :plain,
    enable_starttls_auto: true,
    openssl_verify_mode:  OpenSSL::SSL::VERIFY_PEER
  }

  # I18n fallbacks
  config.i18n.fallbacks = true

  # Active Record
  config.active_record.dump_schema_after_migration = false
  config.active_record.attributes_for_inspect = [:id]

config.hosts.clear

config.hosts << "localhost"
config.hosts << "127.0.0.1"
config.hosts << "0.0.0.0"

# production domains
config.hosts << ENV["APP_HOST"] if ENV["APP_HOST"].present?
config.hosts << /.*\.onrender\.com/
config.hosts << /.*\.fly\.dev/
config.hosts << /.*\.railway\.app/
end