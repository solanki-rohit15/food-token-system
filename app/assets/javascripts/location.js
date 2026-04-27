/**
 * location.js — GPS capture for employees
 *
 * Data flow:
 *   Browser GPS → POST /employee/location → server stores in session
 *   → server response indicates allowed/denied → show/hide GPS banner
 *
 * Lifecycle:
 *   1. On page load, if user role is 'employee', request browser GPS.
 *   2. POST coordinates to /employee/location (server stores in session).
 *   3. Show a dismissible banner if GPS denied or user is outside zone.
 *   4. Re-sends every 5 minutes to keep the session fresh.
 *
 * Access decisions are made server-side in check_location_access.
 * This script only sends data and shows informational banners.
 *
 * Uses a module-level `initialized` flag so that even if turbo:load
 * fires multiple times, only one setInterval is ever created.
 */

(function () {
  'use strict';

  var LOCATION_URL    = '/employee/location';
  var RESEND_INTERVAL = 5 * 60 * 1000;
  var GEO_TIMEOUT     = 10000;
  var initialized     = false;

  function init() {
    var role = getMetaContent('current-user-role');
    if (role !== 'employee') return;

    requestAndSend();

    if (!initialized) {
      initialized = true;
      setInterval(requestAndSend, RESEND_INTERVAL);
    }
  }

  // Request GPS from browser and POST to server
  function requestAndSend() {
    if (!navigator.geolocation) {
      sendToServer(null, null);
      return;
    }

    navigator.geolocation.getCurrentPosition(
      function (pos) {
        sendToServer(pos.coords.latitude, pos.coords.longitude);
      },
      function () {
        sendToServer(null, null);
      },
      {
        enableHighAccuracy: true,
        timeout:            GEO_TIMEOUT,
        maximumAge:         60000
      }
    );
  }

  // POST coordinates to Rails → LocationController#update
  function sendToServer(lat, lng) {
    var csrf = getMetaContent('csrf-token');
    if (!csrf) return;

    var body = {};
    if (lat !== null && lng !== null) {
      body.latitude  = lat;
      body.longitude = lng;
    }

    $.ajax({
      url: LOCATION_URL,
      method: 'POST',
      contentType: 'application/json',
      headers: {
        'X-CSRF-Token': csrf,
        'Accept': 'application/json'
      },
      data: JSON.stringify(body),
      success: function (data) {
        if (data.allowed) {
          removeBanner();
        } else {
          showBanner(data.message, lat !== null);
        }
      },
      error: function () {
        // Network error — will retry on next interval
      }
    });
  }

  // Informational banner — enforcement is server-side
  function showBanner(message, gpsGranted) {
    removeBanner();
    var $banner = $('<div>', { id: 'gps-banner', class: 'gps-banner' });

    $('<span>', {
      class: 'gps-banner__icon',
      text: gpsGranted ? '🚫' : '📍'
    }).appendTo($banner);

    $('<span>', {
      class: 'gps-banner__message',
      text: message
    }).appendTo($banner);

    if (!gpsGranted) {
      $('<button>', {
        type: 'button',
        class: 'gps-banner__retry',
        text: 'Retry'
      }).appendTo($banner);
    }

    $('<button>', {
      type: 'button',
      class: 'gps-banner__close',
      'aria-label': 'Close GPS warning',
      text: '\u00D7'
    }).appendTo($banner);

    $('body').prepend($banner);
  }

  function removeBanner() {
    var b = document.getElementById('gps-banner');
    if (b) b.remove();
  }

  function getMetaContent(name) {
    var el = document.querySelector('meta[name="' + name + '"]');
    return el ? el.getAttribute('content') : null;
  }

  $(document).on('click', '#gps-banner .gps-banner__retry', function () {
    removeBanner();
    requestAndSend();
  });

  $(document).on('click', '#gps-banner .gps-banner__close', function () {
    removeBanner();
  });

  document.addEventListener('turbo:load',       init);
  document.addEventListener('DOMContentLoaded', init);
})();
