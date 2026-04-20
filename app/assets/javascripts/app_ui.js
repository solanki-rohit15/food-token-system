/**
 * app_ui.js — All non-GPS UI interactions
 *
 * Replaces ALL inline <script> blocks from views:
 *   - Password toggle + match indicator
 *   - Meal selection checkbox → button enable
 *   - Token status polling (employee token show page)
 *   - Admin location: radius slider + "use my location"
 *   - Flash message auto-dismiss
 *   - Vendor token: redemption request button
 */


$(document).on('turbo:load DOMContentLoaded', function () {

  // ── Flash auto-dismiss (5s) ───────────────────────────────────────
  setTimeout(() => $('.ft-flash').fadeOut(500, function () { $(this).remove() }), 5000)
  $(document).on('click', '.js-flash-close', function () { $(this).closest('.ft-flash').remove() })

  // ── Password toggle + match indicator ─────────────────────────────
  $(document).on('click', '.btn-pw-toggle', function () {
    const field = $($(this).data('target'))
    const isText = field.attr('type') === 'text'
    field.attr('type', isText ? 'password' : 'text')
    $(this).find('i').toggleClass('bi-eye bi-eye-slash')
  })

  $('#pw-confirm').on('input', function () {
    const pw = $('#pw-field').val()
    const hint = $('#pw-match-hint')
    if (!$(this).val()) { hint.text(''); return }
    if ($(this).val() === pw) {
      hint.text('✓ Passwords match').removeClass('text-danger').addClass('text-success')
    } else {
      hint.text('✗ Passwords do not match').removeClass('text-success').addClass('text-danger')
    }
  })

  // ── Meal selection: enable Generate button ─────────────────────────
  if ($('#meal-form').length) {
    $(document).on('change', '.ft-meal-checkbox', function () {
      const checked = $('.ft-meal-checkbox:checked')
      const names   = checked.map(function () {
        return $(this).closest('.ft-meal-select-item').find('.ft-meal-select-name').text().trim()
      }).get()

      if (names.length) {
        $('#generate-btn').prop('disabled', false)
        $('#selected-count').text(`Selected: ${names.join(', ')}`).removeClass('text-muted').addClass('text-success fw-semibold')
      } else {
        $('#generate-btn').prop('disabled', true)
        $('#selected-count').text('No meals selected').removeClass('text-success fw-semibold').addClass('text-muted')
      }
    })
  }

  // ── Token status polling (employee token show page) ────────────────
  const statusUrl = $('body').data('token-status-url')
  if (statusUrl) {
    let knownState = null
    setInterval(() => {
      $.getJSON(statusUrl, data => {
        const state = JSON.stringify({
          items:   data.order_items.map(i => i.redeemed),
          pending: data.pending_requests.length,
          status:  data.token_status
        })
        if (knownState !== null && knownState !== state) location.reload()
        knownState = state
      })
    }, 5000)
  }

  // ── Admin: radius slider live label ──────────────────────────────
  $('#radius-slider').on('input', function () {
    $('#radius-display').text(`— ${$(this).val()}m`)
  })

  // ── Admin: fill lat/lng from browser GPS ──────────────────────────
  $(document).on('click', '#use-my-location-btn', function () {
    if (!navigator.geolocation) return alert('Geolocation not supported.')
    navigator.geolocation.getCurrentPosition(
      pos => {
        $('input[name="location_setting[latitude]"]').val(pos.coords.latitude.toFixed(6))
        $('input[name="location_setting[longitude]"]').val(pos.coords.longitude.toFixed(6))
      },
      err => alert('Could not get location: ' + err.message),
      { enableHighAccuracy: true, timeout: 10000 }
    )
  })

  // ── Vendor token: per-item redemption request ─────────────────────
  $(document).on('click', '.send-redemption-btn', function () {
    const btn        = $(this)
    const itemId     = btn.data('item-id')
    const label      = btn.data('label')
    const tokenPath  = btn.data('url')
    const csrf       = $('meta[name="csrf-token"]').attr('content')

    setRedemptionButtonLoading(btn)

    $.ajax({
      url:         `${tokenPath}?order_item_id=${itemId}`,
      method:      'POST',
      headers:     { 'X-CSRF-Token': csrf, 'Content-Type': 'application/json' },
      success(data) {
        if (data.success) {
          replaceWithPendingMessage(btn, label)
        } else {
          resetRedemptionButton(btn)
          alert(data.message)
        }
      },
      error() {
        resetRedemptionButton(btn)
        alert('Network error. Please try again.')
      }
    })
  })

  function setRedemptionButtonLoading(btn) {
    const spinner = $('<span>', { class: 'spinner-border spinner-border-sm me-1', 'aria-hidden': 'true' })
    btn.prop('disabled', true).empty().append(spinner).append(document.createTextNode('Sending…'))
  }

  function resetRedemptionButton(btn) {
    const icon = $('<i>', { class: 'bi bi-send me-1', 'aria-hidden': 'true' })
    btn.prop('disabled', false).empty().append(icon).append(document.createTextNode('Request Redemption'))
  }

  function replaceWithPendingMessage(btn, label) {
    const container = $('<div>', { class: 'text-warning small' })
    const icon = $('<i>', { class: 'bi bi-hourglass-split me-1', 'aria-hidden': 'true' })
    container.append(icon).append(document.createTextNode(`Waiting for employee to approve ${label}`))
    btn.replaceWith(container)
  }
})
