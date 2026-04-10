class LocationSetting < ApplicationRecord
  validates :setting_type, presence: true, uniqueness: true
  enum :setting_type, { ip_based: 0, gps_based: 1 }

  def self.ip_setting
    find_or_create_by(setting_type: :ip_based) do |s|
      s.enabled    = false
      s.ip_range   = "192.168.1.0/24"
    end
  end

  def self.gps_setting
    find_or_create_by(setting_type: :gps_based) do |s|
      s.enabled    = false
      s.latitude   = 22.7196
      s.longitude  = 75.8577
      s.radius_meters = 100
    end
  end

  def self.check_ip(request_ip)
    setting = ip_setting
    return true unless setting.enabled?

    require "ipaddr"
    allowed = IPAddr.new(setting.ip_range)
    allowed.include?(IPAddr.new(request_ip))
  rescue IPAddr::InvalidAddressError
    false
  end

  def self.check_gps(lat, lng)
    setting = gps_setting
    return true unless setting.enabled?
    return false unless lat && lng

    distance = haversine_distance(
      setting.latitude, setting.longitude,
      lat.to_f, lng.to_f
    )
    distance <= setting.radius_meters
  end

  def self.haversine_distance(lat1, lon1, lat2, lon2)
    r = 6371000 # Earth radius in meters
    phi1 = lat1 * Math::PI / 180
    phi2 = lat2 * Math::PI / 180
    dphi = (lat2 - lat1) * Math::PI / 180
    dlambda = (lon2 - lon1) * Math::PI / 180

    a = Math.sin(dphi / 2)**2 + Math.cos(phi1) * Math.cos(phi2) * Math.sin(dlambda / 2)**2
    2 * r * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  end
end
