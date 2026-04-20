class Users::SessionsController < Devise::SessionsController
  # GPS location is NOT validated at login time.
  #
  # Why: GPS is asynchronous — the browser cannot guarantee that
  # coordinates will be available at the exact moment a form is submitted.
  # Enforcing location at login causes races, failures, and bad UX.
  #
  # Instead: location.js sends GPS after every page load.
  # check_location_access validates on every subsequent request.
  # If outside the office → employee is signed out immediately.
  #
  # This is simpler, more reliable, and cannot be bypassed.

skip_before_action :check_location_access, raise: false

  def destroy
    # Clear GPS session data on logout
    session.delete(:user_lat)
    session.delete(:user_lng)
    session.delete(:location_at)
    super
  end
end
