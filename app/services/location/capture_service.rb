module Location
  class CaptureService
    Result = Struct.new(:success, :allowed, :status, :message, :http_status, keyword_init: true)

    def initialize(session:)
      @session = session
    end

    def call(latitude:, longitude:)
      lat = latitude.presence
      lng = longitude.presence

      return denied_permission_result unless lat.present? && lng.present?

      lat_f = Float(lat)
      lng_f = Float(lng)
      return invalid_coordinates_result unless valid_coordinates?(lat_f, lng_f)

      persist_coordinates(lat_f, lng_f)

      status = Location::Checker.call(lat: lat_f, lng: lng_f)
      Result.new(
        success: true,
        allowed: status == :allowed,
        status: status,
        message: message_for(status),
        http_status: :ok
      )
    rescue ArgumentError, TypeError
      invalid_coordinates_result
    rescue StandardError => e
      Rails.logger.error("[Location::CaptureService] #{e.class}: #{e.message}")
      Result.new(success: false, allowed: false, message: "Server error.", http_status: :internal_server_error)
    end

    private

    attr_reader :session

    def persist_coordinates(lat, lng)
      session[:user_lat] = lat.round(6)
      session[:user_lng] = lng.round(6)
      session[:location_at] = Time.current.to_i
    end

    def clear_coordinates(stamp:)
      session.delete(:user_lat)
      session.delete(:user_lng)
      session[:location_at] = stamp ? Time.current.to_i : 0
    end

    def denied_permission_result
      clear_coordinates(stamp: true)
      gps_enabled = LocationSetting.gps_setting.enabled?

      Result.new(
        success: true,
        allowed: !gps_enabled,
        status: :no_location,
        message: "Location permission denied.",
        http_status: :ok
      )
    end

    def invalid_coordinates_result
      clear_coordinates(stamp: false)
      Result.new(
        success: false,
        allowed: false,
        status: :no_location,
        message: "Invalid coordinates.",
        http_status: :unprocessable_content
      )
    end

    def valid_coordinates?(lat, lng)
      lat.between?(-90.0, 90.0) && lng.between?(-180.0, 180.0) && !(lat.zero? && lng.zero?)
    end

    def message_for(status)
      case status
      when :allowed then "Location verified."
      when :denied then "Outside office zone."
      else "Office location not configured."
      end
    end
  end
end
