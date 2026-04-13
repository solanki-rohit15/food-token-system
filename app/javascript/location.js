/**
 * location.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Browser-GPS location capture for employees.
 *
 * Flow:
 *   1. On every Turbo page load, if the current user is an employee, attempt
 *      to get GPS coordinates via navigator.geolocation.getCurrentPosition().
 *   2. POST the result (lat/lng or denial) to /employee/location.
 *   3. Server validates against the office location in LocationSetting.
 *   4. If denied/outside, show a non-blocking banner (restriction enforcement
 *      happens server-side via check_location_access before_action).
 *
 * Session caching:
 *   We only re-request GPS every REFRESH_INTERVAL seconds so we don't hammer
 *   the browser permission dialog on every navigation.
 */

const REFRESH_INTERVAL = 5 * 60;   // seconds between re-requests (5 min)
const LOCATION_URL     = '/employee/location';

// ── Entry point ────────────────────────────────────────────────────────────
function initLocationTracking() {
  const roleMeta = document.querySelector('meta[name="current-user-role"]');
  if (!roleMeta || roleMeta.content !== 'employee') return;  // only for employees

  const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content;
  if (!csrfToken) return;

  const lastSent  = parseInt(sessionStorage.getItem('locationSentAt') || '0', 10);
  const now       = Math.floor(Date.now() / 1000);

  // Skip if we sent recently (unless locationGranted is unknown)
  if (now - lastSent < REFRESH_INTERVAL && sessionStorage.getItem('locationGranted') !== null) {
    // Still show banner if denied
    if (sessionStorage.getItem('locationGranted') === 'false') {
      showLocationBanner(null);
    }
    return;
  }

  if (!navigator.geolocation) {
    // Browser has no geolocation support — send null so server can decide
    sendLocation(null, null, null, csrfToken);
    return;
  }

  navigator.geolocation.getCurrentPosition(
    // ── Success ────────────────────────────────────────────────────
    position => {
      const { latitude, longitude, accuracy } = position.coords;
      sendLocation(latitude, longitude, accuracy, csrfToken);
    },
    // ── Denied / error ─────────────────────────────────────────────
    error => {
      console.warn('[FoodToken] Location access denied:', error.message);
      sendLocation(null, null, null, csrfToken);
    },
    {
      enableHighAccuracy: true,
      timeout:            8000,
      maximumAge:         REFRESH_INTERVAL * 1000
    }
  );
}

// ── POST to Rails backend ──────────────────────────────────────────────────
function sendLocation(lat, lng, accuracy, csrfToken) {
  const body = {};
  if (lat !== null) {
    body.latitude  = lat;
    body.longitude = lng;
    body.accuracy  = accuracy;
  }

  fetch(LOCATION_URL, {
    method:  'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': csrfToken,
      'Accept':       'application/json'
    },
    body: JSON.stringify(body)
  })
  .then(r => r.json())
  .then(data => {
    sessionStorage.setItem('locationSentAt', Math.floor(Date.now() / 1000));
    sessionStorage.setItem('locationGranted', lat !== null ? 'true' : 'false');
    sessionStorage.setItem('locationAllowed', data.allowed ? 'true' : 'false');

    if (!data.allowed) {
      showLocationBanner(data);
    } else {
      clearLocationBanner();
    }
  })
  .catch(err => console.warn('[FoodToken] Location send failed:', err));
}

// ── UI banner when location is denied or outside radius ───────────────────
function showLocationBanner(data) {
  clearLocationBanner();

  const granted = sessionStorage.getItem('locationGranted') === 'true';
  const banner  = document.createElement('div');
  banner.id     = 'ft-location-banner';
  banner.className = 'ft-flash ft-flash-warning d-flex align-items-center gap-3';

  if (!granted) {
    banner.innerHTML = `
      <i class="bi bi-geo-alt-fill flex-shrink-0"></i>
      <span class="flex-fill">
        <strong>Location access required.</strong>
        Please allow location permission in your browser to use this system.
      </span>
      <button class="btn btn-sm btn-warning" onclick="retryLocation()">
        <i class="bi bi-arrow-clockwise me-1"></i>Retry
      </button>
      <button class="ft-flash-close" onclick="clearLocationBanner()">&times;</button>
    `;
  } else if (data && data.status === 'denied') {
    const dist = data.distance ? ` (${data.distance}m away)` : '';
    banner.innerHTML = `
      <i class="bi bi-exclamation-triangle-fill flex-shrink-0"></i>
      <span class="flex-fill">
        <strong>Outside office zone${dist}.</strong>
        Some features may be restricted.
      </span>
      <button class="ft-flash-close" onclick="clearLocationBanner()">&times;</button>
    `;
  } else {
    return;  // nothing meaningful to show
  }

  document.body.prepend(banner);
}

function clearLocationBanner() {
  document.getElementById('ft-location-banner')?.remove();
}

function retryLocation() {
  sessionStorage.removeItem('locationSentAt');
  sessionStorage.removeItem('locationGranted');
  clearLocationBanner();
  initLocationTracking();
}

// Expose for inline onclick use
window.retryLocation     = retryLocation;
window.clearLocationBanner = clearLocationBanner;

// ── Run on every Turbo navigation ─────────────────────────────────────────
document.addEventListener('turbo:load', initLocationTracking);
document.addEventListener('DOMContentLoaded', initLocationTracking);
