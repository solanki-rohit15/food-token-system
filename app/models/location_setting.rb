class LocationSetting < ApplicationRecord
  # Only GPS-based restriction exists now. IP-based is fully removed.
  # The table has one row: setting_type = 1 (gps_based).

  enum :setting_type, { gps_based: 1 }

  validates :setting_type, presence: true
  validates :latitude,      numericality: { allow_nil: true }
  validates :longitude,     numericality: { allow_nil: true }
  validates :radius_meters, numericality: { greater_than: 0, allow_nil: true }

  # ── Singleton accessor ────────────────────────────────────────────
  def self.gps_setting
    find_or_create_by!(setting_type: :gps_based) do |s|
      s.name           = "Office"
      s.enabled        = false
      s.latitude       = 22.7196
      s.longitude      = 75.8577
      s.radius_meters  = 100
    end
  end

  # ── Check whether a GPS coordinate is within the allowed radius ───
  #
  # Returns one of:
  #   :allowed   — restriction disabled, or within radius
  #   :denied    — outside radius
  #   :no_location — lat/lng not provided (browser denied permission)
  #
  def self.check(lat, lng)
    setting = gps_setting
    return :allowed unless setting.enabled?
    return :no_location if lat.blank? || lng.blank?

    dist = haversine_distance(
      setting.latitude.to_f,  setting.longitude.to_f,
      lat.to_f,               lng.to_f
    )

    dist <= setting.radius_meters.to_f ? :allowed : :denied
  end

  # ── Haversine formula (metres between two lat/lng points) ─────────
  def self.haversine_distance(lat1, lon1, lat2, lon2)
    r    = 6_371_000   # Earth radius in metres
    phi1 = lat1 * Math::PI / 180
    phi2 = lat2 * Math::PI / 180
    dphi = (lat2 - lat1) * Math::PI / 180
    dlam = (lon2 - lon1) * Math::PI / 180

    a = Math.sin(dphi / 2)**2 +
        Math.cos(phi1) * Math.cos(phi2) * Math.sin(dlam / 2)**2
    2 * r * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  end
end
