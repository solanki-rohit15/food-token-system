class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :enforce_password_change!
  before_action :expire_stale_tokens!, if: -> { user_signed_in? && current_user.employee? }

  rescue_from ActionController::InvalidAuthenticityToken, with: :handle_invalid_authenticity_token
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:account_update, keys: [ :name, :phone ])
  end

  def after_sign_in_path_for(resource)
    resource.must_change_password? ? users_change_password_path : resource.dashboard_path
  end

  def handle_invalid_authenticity_token
    respond_to do |format|
      format.html do
        redirect_to new_user_session_path,
                    alert: "Your session expired or the form became stale. Please try again."
      end
      format.json do
        render json: { success: false, message: "Invalid CSRF token. Refresh and retry." },
               status: :unprocessable_content
      end
    end
  end

  # ─────────────────────────────────────────────────────────────────
  # GPS LOCATION GATE
  #
  # Design (two-step async pattern):
  #   Request 1 → page renders, location.js POSTs GPS in background
  #   Request 2+ → session has coords, we validate here
  #
  # States:
  #   A) GPS restriction OFF        → pass through always
  #   B) location_at never set (0)  → first visit, pass through so JS can run
  #   C) coords nil + stamp > 30s   → GPS was denied, sign out employee
  #   D) coords stale (> 30 min)    → clear session, pass through for re-fetch
  #   E) coords present + fresh     → Haversine check → allow or sign out
  # ─────────────────────────────────────────────────────────────────
  def check_location_access
    setting = LocationSetting.gps_setting

    # A: restriction disabled — everyone passes
    return unless setting&.enabled?

    # Only enforce for employees
    return unless current_user&.employee?

    location_at = session[:location_at].to_i
    lat         = session[:user_lat]
    lng         = session[:user_lng]
    now         = Time.current.to_i
    elapsed     = now - location_at

    # B: truly first visit (JS has not POSTed yet)
    return if location_at.zero?

    # D: stale coords (> 30 min) — wipe and give one free pass for re-fetch
    if elapsed > 30.minutes.to_i
      session.delete(:user_lat)
      session.delete(:user_lng)
      session.delete(:location_at)
      return
    end

    # C: GPS denied/unavailable — stamp exists but coords nil
    #    Deny immediately; employees must provide location to continue.
    if lat.blank? || lng.blank?
      session.delete(:user_lat)
      session.delete(:user_lng)
      session.delete(:location_at)
      sign_out(current_user)
      redirect_to new_user_session_path,
                  alert: "Location permission is required. Please enable GPS and sign in again."
      return
    end

    # E: fresh coords — run distance check
    case Location::Checker.call(lat: lat, lng: lng, setting: setting)
    when :denied
      # Employee is outside the office — sign them out immediately
      session.delete(:user_lat)
      session.delete(:user_lng)
      session.delete(:location_at)
      sign_out(current_user)
      redirect_to new_user_session_path,
                  alert: "Access denied: you are outside the office zone. Please come to the office and sign in again."
    when :no_location
      # Office GPS not configured — log warning, allow through
      Rails.logger.warn("[GPS] Office location not configured. Allowing access.")
    end
    # :allowed → fall through
  end

  private

  def require_admin!
    redirect_to root_path, alert: "Access denied." unless current_user&.admin?
  end

  def require_vendor!
    redirect_to root_path, alert: "Access denied." unless current_user&.vendor?
  end

  def require_employee!
    redirect_to root_path, alert: "Access denied." unless current_user&.employee?
  end

  def safe_parse_date(value)
    Date.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def safe_parse_month(value)
    Date.parse("#{value}-01")
  rescue ArgumentError, TypeError
    nil
  end

  def enforce_password_change!
    return unless user_signed_in?
    return unless current_user.must_change_password?
    return if controller_path.start_with?("users/change_passwords")
    return if devise_controller?

    redirect_to users_change_password_path,
                alert: "Please set a new password before continuing."
  end

  # Bulk-expire any tokens past their expiry time — single UPDATE query.
  # Called on every employee request so the UI always reflects true status.
  def expire_stale_tokens!
    Token.expire_stale!
  rescue StandardError => e
    Rails.logger.error("[expire_stale_tokens!] #{e.class}: #{e.message}")
  end

  def record_not_found
    respond_to do |format|
      format.html { render file: "#{Rails.root}/public/404.html", layout: false, status: :not_found }
      format.json { render json: { error: "Record not found" }, status: :not_found }
    end
  end
end
