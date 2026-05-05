/**
 * api.js — Centralised AJAX helper
 *
 * Provides a single apiRequest() function used by scanner.js,
 * dashboard.js, and any other module that needs to talk to the backend.
 *
 * Usage:
 *   apiRequest({ url: '/vendor/scan/verify', method: 'POST', body: { qr_data: '...' } })
 *     .then(data => ...)
 *     .catch(err => ...)
 */
(function (global) {
  'use strict';

  function getCsrf() {
    var el = document.querySelector('meta[name="csrf-token"]');
    return el ? el.getAttribute('content') : '';
  }

  /**
   * apiRequest(options) → Promise<data>
   *
   * Options:
   *   url     {string}  required
   *   method  {string}  default: 'GET'
   *   body    {object}  optional — will be JSON-stringified
   *   params  {object}  optional — added as query string for GET
   *
   * Throws on HTTP error (status >= 400).
   * Always returns parsed JSON.
   */
  function apiRequest(options) {
    var method  = (options.method || 'GET').toUpperCase();
    var url     = options.url;

    if (options.params && method === 'GET') {
      var qs = Object.keys(options.params)
        .filter(function (k) { return options.params[k] !== null && options.params[k] !== undefined && options.params[k] !== ''; })
        .map(function (k) { return encodeURIComponent(k) + '=' + encodeURIComponent(options.params[k]); })
        .join('&');
      if (qs) url += (url.includes('?') ? '&' : '?') + qs;
    }

    var fetchOptions = {
      method:      method,
      headers:     {
        'Content-Type': 'application/json',
        'Accept':       'application/json',
        'X-CSRF-Token': getCsrf()
      },
      credentials: 'same-origin'
    };

    if (options.body && method !== 'GET') {
      fetchOptions.body = JSON.stringify(options.body);
    }

    return fetch(url, fetchOptions).then(function (response) {
      return response.json().then(function (data) {
        if (!response.ok) {
          var err = new Error(data.message || data.error || 'Request failed');
          err.status = response.status;
          err.data   = data;
          throw err;
        }
        return data;
      });
    });
  }

  global.FT = global.FT || {};
  global.FT.apiRequest = apiRequest;
  global.FT.getCsrf    = getCsrf;

})(window);
