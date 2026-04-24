/**
 * app_ui.js — All non-GPS UI interactions
 *
 * 
 *   - Password toggle + match indicator
 *   - Meal selection checkbox → button enable
 *   - Token status polling (employee token show page)
 *   - Admin location: radius slider + "use my location"
 *   - Flash message auto-dismiss
 *   - Vendor token: redemption request button
 */


function initAppUi() {
  if (window.__appUiInitialized) return
  window.__appUiInitialized = true

  const csrfToken = $('meta[name="csrf-token"]').attr('content')

  function showFlash(type, message) {
    if (!message) return

    $('.ft-flash').remove()

    const isError = type === 'error'
    const flash = $('<div>', {
      class: `ft-flash ${isError ? 'ft-flash-danger' : 'ft-flash-success'}`
    })
    const icon = $('<i>', { class: isError ? 'bi bi-exclamation-triangle-fill me-2' : 'bi bi-check-circle-fill me-2' })
    const closeBtn = $('<button>', {
      type: 'button',
      class: 'ft-flash-close js-flash-close',
      'aria-label': 'Dismiss message'
    }).text('×')

    flash.append(icon).append(document.createTextNode(message)).append(closeBtn)
    $('body').prepend(flash)
    setTimeout(() => flash.fadeOut(500, function () { $(this).remove() }), 5000)
  }

  async function submitWithFetch(formEl) {
    const action = formEl.getAttribute('action')
    const methodInput = formEl.querySelector('input[name="_method"]')
    const method = (methodInput ? methodInput.value : formEl.getAttribute('method') || 'POST').toUpperCase()
    const formData = new FormData(formEl)

    const response = await fetch(action, {
      method,
      headers: {
        'X-CSRF-Token': csrfToken,
        'Accept': 'application/json'
      },
      body: formData,
      credentials: 'same-origin'
    })

    let data = {}
    try {
      data = await response.json()
    } catch (_error) {
      data = { success: false, message: 'Unexpected response from server.' }
    }

    return { ok: response.ok, data }
  }

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

  // ── Admin fetch forms/actions (no full page reload) ───────────────
  async function handleAjaxFormSubmit(formEl, event) {
    if (event) {
      event.preventDefault()
      event.stopPropagation()
    }
    const submitBtn = formEl.querySelector('button[type="submit"], input[type="submit"]')
    const confirmMessage = formEl.getAttribute('data-confirm') || (submitBtn ? submitBtn.getAttribute('data-confirm') : null)
    if (confirmMessage && !window.confirm(confirmMessage)) return

    if (submitBtn) submitBtn.disabled = true

    try {
      const { ok, data } = await submitWithFetch(formEl)

      if (!ok || data.success === false) {
        showFlash('error', data.message || 'Action failed.')
        return
      }

      if ($(formEl).hasClass('js-user-toggle-form')) {
        const btn = $(formEl).find('.js-user-toggle-btn')
        const statusCell = $(`#user_status_${data.id}`)
        if (statusCell.length) {
          statusCell.html(data.active ? '<span class="badge bg-success">Active</span>' : '<span class="badge bg-secondary">Inactive</span>')
        }
        if (btn.length) {
          btn.text(data.active ? 'Deactivate' : 'Activate')
          btn.removeClass('btn-outline-warning btn-outline-success')
          btn.addClass(data.active ? 'btn-outline-warning' : 'btn-outline-success')
        }
      } else if ($(formEl).hasClass('js-user-delete-form')) {
        $(`#user_row_${data.id}`).fadeOut(200, function () { $(this).remove() })
      } else if ($(formEl).hasClass('js-user-show-toggle-form')) {
        const btn = $(formEl).find('.js-user-show-toggle-btn')
        const badgeWrap = $(`#user_show_status_badge_${data.id}`)
        if (badgeWrap.length) {
          badgeWrap.html(data.active ? '<span class="badge bg-success">Active</span>' : '<span class="badge bg-secondary">Inactive</span>')
        }
        if (btn.length) {
          btn.text(data.active ? 'Deactivate' : 'Activate')
          btn.removeClass('btn-outline-warning btn-outline-success')
          btn.addClass(data.active ? 'btn-outline-warning' : 'btn-outline-success')
        }
      }

      showFlash('success', data.message || 'Saved successfully.')
    } catch (_error) {
      showFlash('error', 'Network error. Please try again.')
    } finally {
      if (submitBtn) submitBtn.disabled = false
    }
  }

  document.addEventListener('submit', function (event) {
    const formEl = event.target
    if (!(formEl instanceof HTMLFormElement)) return
    if (!formEl.matches('.js-fetch-form[data-ajax="true"]')) return
    handleAjaxFormSubmit(formEl, event)
  }, true)

  window.handleAjaxFormSubmit = function (event, formEl) {
    handleAjaxFormSubmit(formEl, event)
    return false
  }
}

$(initAppUi)
$(document).on('turbo:load', initAppUi)
