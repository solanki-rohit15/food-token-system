# Employee::LocationController
#
# Receives GPS coordinates from location.js and stores them in the
# encrypted Rails session. This is the ONLY place GPS data enters
# the server. All access decisions happen in check_location_access.
#
# This endpoint MUST skip check_location_access — it IS the GPS
# submission endpoint, so blocking it creates a deadlock.
class Employee::LocationController < ApplicationController
  skip_before_action :check_location_access, raise: false
  before_action :authenticate_user!

  # POST /employee/location
  # Body: { latitude: Float, longitude: Float }
  def update
    result = Location::CaptureService.new(session: session).call(
      latitude: params[:latitude],
      longitude: params[:longitude]
    )

    render json: {
      success: result.success,
      allowed: result.allowed,
      status: result.status,
      message: result.message
    }, status: result.http_status
  end
end
