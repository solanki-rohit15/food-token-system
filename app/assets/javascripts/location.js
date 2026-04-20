/**
 * location.js — GPS capture for employees
 *
 * WHAT THIS FILE DOES:
 *   1. On every page load, if user is an employee, request browser GPS.
 *   2. POST coordinates to /employee/location (server stores in session).
 *   3. Show a dismissible banner if GPS denied or outside zone.
 *   4. Re-sends every RESEND_INTERVAL seconds (keeps session fresh).
 *
 * WHAT THIS FILE DOES NOT DO:
 *   - Make access decisions (server does that via check_location_access).
 *   - Block navigation (server redirects / signs out if needed).
 *   - Store anything in localStorage or sessionStorage.
 *
 * SINGLE INTERVAL GUARANTEE:
 *   Uses a module-level `initialized` flag so that even if turbo:load
 *   fires multiple times, only one setInterval is ever created.
 */

(function () {
  'use strict';

  var LOCATION_URL     = '/employee/location';
  var RESEND_INTERVAL  = 5 * 60 * 1000; // 5 minutes in ms
  var GEO_TIMEOUT      = 10000;          // 10 seconds for browser GPS
  var initialized      = false;          // ← prevents duplicate intervals

  // ── Entry point ────────────────────────────────────────────────
  function init() {
    var role = getMetaContent('current-user-role');
    // Only run for employees. Vendors and admins are never GPS-gated.
    if (role !== 'employee') return;

    // Send immediately on first call
    requestAndSend();

    // Start the refresh interval ONCE — guard against turbo:load firing
    // multiple times on the same page session.
    if (!initialized) {
      initialized = true;
      setInterval(requestAndSend, RESEND_INTERVAL);
    }
  }

  // ── Request GPS from browser ───────────────────────────────────
  function requestAndSend() {
    if (!navigator.geolocation) {
      // Browser has no GPS support
      sendToServer(null, null);
      return;
    }

    navigator.geolocation.getCurrentPosition(
      function (pos) {
        sendToServer(pos.coords.latitude, pos.coords.longitude);
      },
      function (err) {
        // User denied permission or GPS unavailable
        sendToServer(null, null);
      },
      {
        enableHighAccuracy: true,
        timeout:            GEO_TIMEOUT,
        maximumAge:         60000   // accept a cached fix up to 1 min old
      }
    );
  }

  // ── POST coordinates to Rails ──────────────────────────────────
  function sendToServer(lat, lng) {
    var csrf = getMetaContent('csrf-token');
    if (!csrf) return;  // page not fully loaded

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
        // Network error — do nothing, will retry on next interval
      }
    });
  }

  // ── Banner (informational only — enforcement is server-side) ──
  function showBanner(message, gpsGranted) {
    removeBanner();
    var $banner = $('<div>', {
      id: 'gps-banner',
      class: 'gps-banner'
    });

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

  // ── Hooks ──────────────────────────────────────────────────────
  // turbo:load fires on every Turbo navigation.
  // DOMContentLoaded fires on hard page loads (no Turbo).
  // Both call init(), but the `initialized` flag prevents duplicate intervals.
  document.addEventListener('turbo:load',       init);
  document.addEventListener('DOMContentLoaded', init);

})(); // IIFE
