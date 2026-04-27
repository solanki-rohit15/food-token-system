/**
 * app_ui.js — Non-GPS UI interactions (jQuery)
 *
 * Modules:
 *   1. Flash messages — auto-dismiss after 5s, manual dismiss via close button
 *   2. Password toggle + match indicator — change password page
 *   3. Meal selection checkbox → generate button enable/disable
 *   4. Token status polling — employee token show page, auto-reload on state change
 *   5. Admin location — radius slider + "use my location" browser GPS
 *   6. Vendor token — per-item redemption request with loading state
 *   7. Admin AJAX forms — submit via fetch, update DOM without page reload
 */

function initAppUi() {
  if (window.__appUiInitialized) return
  window.__appUiInitialized = true

  var csrfToken = $('meta[name="csrf-token"]').attr('content')

  // ── Reusable flash message ───────────────────────────────────────
  // Creates a fixed-position toast notification at top-right.
  // type: 'error' (red) | 'success' (green)
  function showFlash(type, message) {
    if (!message) return

    $('.ft-flash').remove()

    var isError = type === 'error'
    var flash = $('<div>', {
      class: 'ft-flash ' + (isError ? 'ft-flash-danger' : 'ft-flash-success')
    })
    var icon = $('<i>', { class: isError ? 'bi bi-exclamation-triangle-fill me-2' : 'bi bi-check-circle-fill me-2' })
    var closeBtn = $('<button>', {
      type: 'button',
      class: 'ft-flash-close js-flash-close',
      'aria-label': 'Dismiss message'
    }).text('×')

    flash.append(icon).append(document.createTextNode(message)).append(closeBtn)
    $('body').prepend(flash)
    setTimeout(function () { flash.fadeOut(500, function () { $(this).remove() }) }, 5000)
  }

  // ── Reusable AJAX form submit ────────────────────────────────────
  // Posts form data via fetch, returns { ok, data } for callers to handle.
  async function submitWithFetch(formEl) {
    var action = formEl.getAttribute('action')
    var methodInput = formEl.querySelector('input[name="_method"]')
    var method = (methodInput ? methodInput.value : formEl.getAttribute('method') || 'POST').toUpperCase()
    var formData = new FormData(formEl)

    var response = await fetch(action, {
      method: method,
      headers: {
        'X-CSRF-Token': csrfToken,
        'Accept': 'application/json'
      },
      body: formData,
      credentials: 'same-origin'
    })

    var data = {}
    try {
      data = await response.json()
    } catch (_error) {
      data = { success: false, message: 'Unexpected response from server.' }
    }

    return { ok: response.ok, data: data }
  }

  // ── Flash auto-dismiss (5s for server-rendered flash) ─────────────
  setTimeout(function () { $('.ft-flash').fadeOut(500, function () { $(this).remove() }) }, 5000)
  $(document).on('click', '.js-flash-close', function () { $(this).closest('.ft-flash').remove() })

  // ── Password toggle + match indicator ─────────────────────────────
  $(document).on('click', '.btn-pw-toggle', function () {
    var field = $($(this).data('target'))
    var isText = field.attr('type') === 'text'
    field.attr('type', isText ? 'password' : 'text')
    $(this).find('i').toggleClass('bi-eye bi-eye-slash')
  })

  $('#pw-confirm').on('input', function () {
    var pw = $('#pw-field').val()
    var hint = $('#pw-match-hint')
    if (!$(this).val()) { hint.text(''); return }
    if ($(this).val() === pw) {
      hint.text('✓ Passwords match').removeClass('text-danger').addClass('text-success')
    } else {
      hint.text('✗ Passwords do not match').removeClass('text-success').addClass('text-danger')
    }
  })

  // ── Meal selection: enable Generate button when items checked ─────
  if ($('#meal-form').length) {
    $(document).on('change', '.ft-meal-checkbox', function () {
      var checked = $('.ft-meal-checkbox:checked')
      var names = checked.map(function () {
        return $(this).closest('.ft-meal-select-item').find('.ft-meal-select-name').text().trim()
      }).get()

      if (names.length) {
        $('#generate-btn').prop('disabled', false)
        $('#selected-count').text('Selected: ' + names.join(', ')).removeClass('text-muted').addClass('text-success fw-semibold')
      } else {
        $('#generate-btn').prop('disabled', true)
        $('#selected-count').text('No meals selected').removeClass('text-success fw-semibold').addClass('text-muted')
      }
    })
  }

  // ── Token status polling (employee token show page) ───────────────
  // Polls token status JSON every 5s. On any state change (items redeemed,
  // new pending request, status flip), reloads the page to show fresh UI.
  var statusUrl = $('body').data('token-status-url')
  if (statusUrl) {
    window.__tokenKnownState = null
    setInterval(function () {
      $.getJSON(statusUrl, function (data) {
        var state = JSON.stringify({
          items:   data.order_items.map(function (i) { return i.redeemed }),
          pending: data.pending_requests.length,
          status:  data.token_status
        })
        if (window.__tokenKnownState !== null && window.__tokenKnownState !== state) {
          location.reload()
        }
        window.__tokenKnownState = state
      })
    }, 5000)
  }

  // ── Admin: radius slider live label ──────────────────────────────
  $('#radius-slider').on('input', function () {
    $('#radius-display').text('— ' + $(this).val() + 'm')
  })

  // ── Admin: fill lat/lng from browser GPS ──────────────────────────
  $(document).on('click', '#use-my-location-btn', function () {
    if (!navigator.geolocation) return alert('Geolocation not supported.')
    navigator.geolocation.getCurrentPosition(
      function (pos) {
        $('input[name="location_setting[latitude]"]').val(pos.coords.latitude.toFixed(6))
        $('input[name="location_setting[longitude]"]').val(pos.coords.longitude.toFixed(6))
      },
      function (err) { alert('Could not get location: ' + err.message) },
      { enableHighAccuracy: true, timeout: 10000 }
    )
  })

  // ── Vendor token show: per-item redemption request ────────────────
  // Flow: button click → loading spinner → POST to send_redemption_request
  //       → on success: replace button with "Waiting for approval" message
  //       → on failure: restore button, show alert
  $(document).on('click', '.send-redemption-btn', function () {
    var btn       = $(this)
    var itemId    = btn.data('item-id')
    var label     = btn.data('label')
    var tokenPath = btn.data('url')

    setButtonLoading(btn)

    $.ajax({
      url:     tokenPath + '?order_item_id=' + itemId,
      method:  'POST',
      headers: { 'X-CSRF-Token': csrfToken, 'Content-Type': 'application/json' },
      success: function (data) {
        if (data.success) {
          replaceWithPendingMessage(btn, label)
        } else {
          resetButton(btn)
          alert(data.message)
        }
      },
      error: function () {
        resetButton(btn)
        alert('Network error. Please try again.')
      }
    })
  })

  // ── Shared button state helpers ──────────────────────────────────
  function setButtonLoading(btn) {
    var spinner = $('<span>', { class: 'spinner-border spinner-border-sm me-1', 'aria-hidden': 'true' })
    btn.prop('disabled', true).empty().append(spinner).append(document.createTextNode('Sending…'))
  }

  function resetButton(btn) {
    var icon = $('<i>', { class: 'bi bi-send me-1', 'aria-hidden': 'true' })
    btn.prop('disabled', false).empty().append(icon).append(document.createTextNode('Request Redemption'))
  }

  function replaceWithPendingMessage(btn, label) {
    var container = $('<div>', { class: 'text-warning small' })
    var icon = $('<i>', { class: 'bi bi-hourglass-split me-1', 'aria-hidden': 'true' })
    container.append(icon).append(document.createTextNode('Waiting for employee to approve ' + label))
    btn.replaceWith(container)
  }

  // ── Admin AJAX forms — submit via fetch, update DOM in-place ──────
  // Forms with class .js-fetch-form[data-ajax="true"] are intercepted.
  // The response JSON is used to update status badges, remove rows, etc.
  async function handleAjaxFormSubmit(formEl, event) {
    if (event) {
      event.preventDefault()
      event.stopPropagation()
    }

    var submitBtn = formEl.querySelector('button[type="submit"], input[type="submit"]')
    var confirmMessage = formEl.getAttribute('data-confirm') || (submitBtn ? submitBtn.getAttribute('data-confirm') : null)
    if (confirmMessage && !window.confirm(confirmMessage)) return

    if (submitBtn) submitBtn.disabled = true

    try {
      var result = await submitWithFetch(formEl)
      var ok = result.ok
      var data = result.data

      if (!ok || data.success === false) {
        showFlash('error', data.message || 'Action failed.')
        return
      }

      // User toggle (index page) — update status badge + button text
      if ($(formEl).hasClass('js-user-toggle-form')) {
        var btn = $(formEl).find('.js-user-toggle-btn')
        var statusCell = $('#user_status_' + data.id)
        if (statusCell.length) {
          var badgeSpan = $('<span>', {
            class: data.active ? 'badge bg-success' : 'badge bg-secondary',
            text: data.active ? 'Active' : 'Inactive'
          })
          statusCell.empty().append(badgeSpan)
        }
        if (btn.length) {
          btn.text(data.active ? 'Deactivate' : 'Activate')
          btn.removeClass('btn-outline-warning btn-outline-success')
          btn.addClass(data.active ? 'btn-outline-warning' : 'btn-outline-success')
        }

      // User delete — fade out row
      } else if ($(formEl).hasClass('js-user-delete-form')) {
        $('#user_row_' + data.id).fadeOut(200, function () { $(this).remove() })

      // User toggle (show page) — update show-page badge + button
      } else if ($(formEl).hasClass('js-user-show-toggle-form')) {
        var showBtn = $(formEl).find('.js-user-show-toggle-btn')
        var badgeWrap = $('#user_show_status_badge_' + data.id)
        if (badgeWrap.length) {
          var badgeSpan = $('<span>', {
            class: data.active ? 'badge bg-success' : 'badge bg-secondary',
            text: data.active ? 'Active' : 'Inactive'
          })
          badgeWrap.empty().append(badgeSpan)
        }
        if (showBtn.length) {
          showBtn.text(data.active ? 'Deactivate' : 'Activate')
          showBtn.removeClass('btn-outline-warning btn-outline-success')
          showBtn.addClass(data.active ? 'btn-outline-warning' : 'btn-outline-success')
        }

      // Employee Redemption Approve
      } else if ($(formEl).hasClass('js-redemption-approve-form')) {
        $('#pending_req_' + data.request_id).fadeOut(200, function () { $(this).remove() })
        
        var card = $('#qr_card_' + data.order_item_id)
        if (card.length) {
          card.removeClass('border-primary').addClass('border-success opacity-75')
          
          var timeStr = new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
          var badgeSpan = $('<span>', { class: 'badge bg-success', text: '✅ ' + timeStr })
          $('#qr_card_badge_' + data.order_item_id).empty().append(badgeSpan)
          
          var bodyDiv = $('<div>', { class: 'card-body text-center py-3 text-success' })
          var iconNode = $('<i>', { class: 'bi bi-check-circle-fill fs-1' })
          var textNode = $('<div>', { class: 'mt-1 small', text: 'Redeemed by vendor' })
          
          bodyDiv.append(iconNode).append(textNode)
          $('#qr_card_body_' + data.order_item_id).empty().append(bodyDiv)
        }
        
        // Reset known state so the polling script doesn't reload immediately
        window.__tokenKnownState = null

      // Employee Redemption Reject
      } else if ($(formEl).hasClass('js-redemption-reject-form')) {
        $('#pending_req_' + data.request_id).fadeOut(200, function () { $(this).remove() })
        
        var cardBadge = $('#qr_card_badge_' + data.order_item_id)
        if (cardBadge.length) {
          var activeSpan = $('<span>', { class: 'badge bg-light border text-dark', text: 'Active' })
          cardBadge.empty().append(activeSpan)
        }
        
        // Reset known state so the polling script doesn't reload immediately
        window.__tokenKnownState = null
      }

      showFlash('success', data.message || 'Saved successfully.')
    } catch (_error) {
      showFlash('error', 'Network error. Please try again.')
    } finally {
      if (submitBtn) submitBtn.disabled = false
    }
  }

  // Global event listener — intercept all AJAX form submissions
  document.addEventListener('submit', function (event) {
    var formEl = event.target
    if (!(formEl instanceof HTMLFormElement)) return
    if (!formEl.matches('.js-fetch-form[data-ajax="true"]')) return
    handleAjaxFormSubmit(formEl, event)
  }, true)
}

// Initialize on jQuery ready and Turbo navigation
$(initAppUi)
$(document).on('turbo:load', initAppUi)
