require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }
  config.active_storage.service = :local

  # Enforce SSL in production
  config.assume_ssl  = true
  config.force_ssl   = true
  config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")
  config.silence_healthcheck_path = "/up"
  config.active_support.report_deprecations = false

  config.cache_store = :memory_store
  config.active_job.queue_adapter = :async

  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.default_url_options   = {
    host:     ENV.fetch("APP_HOST", "example.com"),
    protocol: "https"
  }
  config.action_mailer.delivery_method = :smtp
  smtp_port = ENV.fetch("SMTP_PORT", "587").to_i
  config.action_mailer.smtp_settings = {
    address:              ENV.fetch("SMTP_HOST", "smtp.gmail.com"),
    port:                 smtp_port,
    domain:               ENV.fetch("SMTP_DOMAIN", "gmail.com"),
    user_name:            ENV.fetch("SMTP_USER", ""),
    password:             ENV.fetch("SMTP_PASSWORD", ""),
    authentication:       :plain,
    enable_starttls_auto: smtp_port != 465,
    tls:                  smtp_port == 465,
    open_timeout:         30,
    read_timeout:         30
  }

  config.i18n.fallbacks = true
  config.active_record.dump_schema_after_migration = false
  config.active_record.attributes_for_inspect      = [ :id ]

  # Host whitelist — set APP_HOST in your environment
  config.hosts = [
    ENV.fetch("APP_HOST", nil),
    /.*\.fly\.dev/,
    /.*\.railway\.app/,
    /.*\.render\.com/
  ].compact
end
