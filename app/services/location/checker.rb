module Location
  class Checker
    class << self
      # Returns: :allowed | :denied | :no_location
      def call(lat:, lng:, setting: LocationSetting.gps_setting)
        return :allowed unless setting.enabled?
        return :no_location if lat.blank? || lng.blank?
        return :no_location if setting.latitude.blank? || setting.longitude.blank?

        user_lat = Float(lat)
        user_lng = Float(lng)
        return :no_location unless valid_coordinates?(user_lat, user_lng)

        office_coordinates = [ setting.latitude.to_f, setting.longitude.to_f ]
        user_coordinates = [ user_lat, user_lng ]

        distance_meters = Geocoder::Calculations.distance_between(office_coordinates, user_coordinates) * 1000
        distance_meters <= setting.radius_meters.to_f ? :allowed : :denied
      rescue ArgumentError, TypeError
        :no_location
      rescue StandardError => e
        Rails.logger.error("[Location::Checker] #{e.class}: #{e.message}")
        :no_location
      end

      private

      def valid_coordinates?(lat, lng)
        lat.between?(-90.0, 90.0) && lng.between?(-180.0, 180.0) && !(lat.zero? && lng.zero?)
      end
    end
  end
end
