ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup"
require "bootsnap/setup"
require "digest"

# Render deployment: ensure secret_key_base is available before any gem loads.
# Uses plain Ruby .nil? and .empty? — NOT .blank? (that's ActiveSupport, not loaded yet).
if ENV["RAILS_ENV"] == "production"
  secret_key_base = ENV["SECRET_KEY_BASE"]
  rails_master_key = ENV["RAILS_MASTER_KEY"]

  # An invalid master key can trigger OpenSSL key-size errors during boot.
  if rails_master_key && !rails_master_key.empty? && rails_master_key !~ /\A\h{32}\z/
    warn "[boot] Ignoring invalid RAILS_MASTER_KEY format in production"
    ENV.delete("RAILS_MASTER_KEY")
  end

  if secret_key_base.nil? || secret_key_base.empty?
    ENV["SECRET_KEY_BASE"] = "0" * 128
  elsif secret_key_base.length < 64
    # Normalize too-short values into a stable, high-entropy key.
    ENV["SECRET_KEY_BASE"] = Digest::SHA512.hexdigest(secret_key_base)
  end
end
