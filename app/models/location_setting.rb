class LocationSetting < ApplicationRecord
  enum :setting_type, { gps_based: 1 }

  validates :setting_type,  presence: true
  validates :latitude,      numericality: { allow_nil: true }
  validates :longitude,     numericality: { allow_nil: true }
  validates :radius_meters, numericality: { greater_than: 0, allow_nil: true }

  with_options if: :enabled? do
    validates :latitude,      presence: true
    validates :longitude,     presence: true
    validates :radius_meters, presence: true
  end

  # ── Singleton ─────────────────────────────────────────────────────
  def self.gps_setting
    find_or_create_by!(setting_type: :gps_based) do |s|
      s.name          = "Office"
      s.enabled       = false
      s.latitude      = 22.7196
      s.longitude     = 75.8577
      s.radius_meters = 200
    end
  end

  # ── Main access check ─────────────────────────────────────────────
  # Returns: :allowed | :denied | :no_location
  def self.check(lat, lng)
    Location::Checker.call(lat: lat, lng: lng, setting: gps_setting)
  rescue StandardError => e
    Rails.logger.error("[LocationSetting.check] #{e.class}: #{e.message}")
    :no_location
  end
end
