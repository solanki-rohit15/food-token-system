/**
 * scanner.js — Vendor QR scanner (jQuery)
 *
 * Only activates when #scanner-page exists in the DOM.
 * jsQR is loaded via CDN <script> in the scanner view head,
 * available as window.jsQR before this module runs.
 */


$(document).on('turbo:load DOMContentLoaded', function () {
  const $page = $('#scanner-page')
  if (!$page.length) return  // guard — only run on scanner page

  const verifyUrl = $page.data('verify-url')
  const csrf      = $('meta[name="csrf-token"]').attr('content')
  let tokenId     = null
  let scanning    = true

  const video  = document.getElementById('qr-video')
  const canvas = document.getElementById('qr-canvas')
  const ctx    = canvas.getContext('2d')

  // ── Start camera ─────────────────────────────────────────────────
  if (navigator.mediaDevices?.getUserMedia) {
    navigator.mediaDevices
      .getUserMedia({ video: { facingMode: 'environment' } })
      .then(stream => { video.srcObject = stream; video.play(); requestAnimationFrame(tick) })
      .catch(() => {})
  }

  function tick() {
    if (!scanning) return
    if (video.readyState === video.HAVE_ENOUGH_DATA) {
      canvas.height = video.videoHeight
      canvas.width  = video.videoWidth
      ctx.drawImage(video, 0, 0, canvas.width, canvas.height)
      const img  = ctx.getImageData(0, 0, canvas.width, canvas.height)
      const code = window.jsQR?.(img.data, img.width, img.height, { inversionAttempts: 'dontInvert' })
      if (code) { scanning = false; verifyCode(code.data); return }
    }
    requestAnimationFrame(tick)
  }

  // ── Manual entry ─────────────────────────────────────────────────
  $('#verify-manual-btn').on('click', function () {
    const val = $('#manual-qr').val().trim()
    if (val) { scanning = false; verifyCode(val) }
  })

  $('#manual-qr').on('keypress', function (e) {
    if (e.key === 'Enter') { scanning = false; verifyCode($(this).val().trim()) }
  })

  // ── Verify QR code ───────────────────────────────────────────────
  function verifyCode(data) {
    $.ajax({
      url:         verifyUrl,
      method:      'POST',
      contentType: 'application/json',
      headers:     { 'X-CSRF-Token': csrf },
      data:        JSON.stringify({ qr_data: data }),
      success:     handleResult,
      error() { alert('Error verifying. Please try again.'); scanning = true }
    })
  }

  function handleResult(result) {
    $('#scan-result').removeClass('d-none')
    $('#camera-view').addClass('d-none')

    if (result.valid) {
      tokenId = result.token_id
      $('#result-valid').removeClass('d-none')
      $('#result-invalid').addClass('d-none')
      $('#emp-initials').text(result.employee.initials)
      $('#emp-name').text(result.employee.name)
      $('#emp-email').text(result.employee.email)
      $('#emp-dept').text(result.employee.department || '')
      $('#token-id-disp').text(result.token_number)
      $('#token-expiry').text(result.expires_at)

      if (result.scanned_item) {
        $('#scanned-item-info').removeClass('d-none')
        $('#scanned-item-badge').text(result.scanned_item.category)
      } else {
        $('#scanned-item-info').addClass('d-none')
      }

      renderItems(result.items, result.scanned_item)
    } else {
      $('#result-invalid').removeClass('d-none')
      $('#result-valid').addClass('d-none')
      $('#invalid-message').text(result.message)
    }
  }

  // ── Render per-item list + request buttons ────────────────────────
  function renderItems(items, scannedItem) {
    const $items   = $('#token-items').empty()
    const $buttons = $('#request-buttons-container').empty()

    items.forEach(item => {
      const highlight = scannedItem?.item_code === item.item_code ? 'border border-primary' : ''
      const itemIconLabel = `${item.icon} ${item.label}`

      const $itemRow = $('<div>', { class: `d-flex align-items-center gap-2 p-2 rounded ${highlight} bg-light` })
      $('<span>', { text: itemIconLabel }).appendTo($itemRow)
      createItemBadge(item.redeemed).appendTo($itemRow)
      $items.append($itemRow)

      if (!item.redeemed && item.order_item_id) {
        $buttons.append(createScanRequestButton(item))
      }
    })

    if (!$buttons.children().length) {
      $('<div>', {
        class: 'alert alert-success mb-0',
        text: 'All items have been redeemed.'
      }).appendTo($buttons)
    }
  }

  // ── Send per-item redemption request ─────────────────────────────
  $(document).on('click', '.send-scan-req', function () {
    const $btn   = $(this)
    const itemId = $btn.data('item-id')
    const label  = $btn.data('label')

    setScanRequestButtonLoading($btn)

    $.ajax({
      url:         `/vendor/tokens/${tokenId}/send_redemption_request?order_item_id=${itemId}`,
      method:      'POST',
      headers:     { 'X-CSRF-Token': csrf, 'Content-Type': 'application/json' },
      success(data) {
        if (data.success) {
          $btn.replaceWith(createRequestSentAlert(label))
        } else {
          resetScanRequestButton($btn, label)
          alert(data.message)
        }
      },
      error() {
        resetScanRequestButton($btn, label)
        alert('Network error. Please try again.')
      }
    })
  })

  function createItemBadge(redeemed) {
    if (redeemed) {
      return $('<span>', { class: 'badge bg-success ms-auto', text: '✅ Redeemed' })
    }
    return $('<span>', { class: 'badge bg-warning text-dark ms-auto', text: '⏳ Pending' })
  }

  function createScanRequestButton(item) {
    const labelText = `Request: ${item.icon} ${item.label}`
    const $button = $('<button>', {
      type: 'button',
      class: 'btn btn-primary w-100 mb-2 send-scan-req'
    })
      .attr('data-item-id', item.order_item_id)
      .attr('data-label', item.label)

    $('<i>', { class: 'bi bi-send me-2', 'aria-hidden': 'true' }).appendTo($button)
    $button.append(document.createTextNode(labelText))
    return $button
  }

  function setScanRequestButtonLoading($btn) {
    const spinner = $('<span>', { class: 'spinner-border spinner-border-sm me-2', 'aria-hidden': 'true' })
    $btn.prop('disabled', true).empty().append(spinner).append(document.createTextNode('Sending…'))
  }

  function resetScanRequestButton($btn, label) {
    const icon = $('<i>', { class: 'bi bi-send me-2', 'aria-hidden': 'true' })
    $btn.prop('disabled', false).empty().append(icon).append(document.createTextNode(`Request: ${label}`))
  }

  function createRequestSentAlert(label) {
    const $alert = $('<div>', { class: 'alert alert-success mb-2' })
    $('<i>', { class: 'bi bi-check-circle me-1', 'aria-hidden': 'true' }).appendTo($alert)
    $alert.append(document.createTextNode('Request sent for '))
    $('<strong>', { text: label }).appendTo($alert)
    $alert.append(document.createTextNode(' — waiting for approval'))
    return $alert
  }

  // ── Reset scanner ────────────────────────────────────────────────
  function resetScanner() {
    tokenId  = null
    scanning = true
    $('#scan-result').addClass('d-none')
    $('#camera-view').removeClass('d-none')
    $('#result-valid, #result-invalid').addClass('d-none')
    $('#manual-qr').val('')
    requestAnimationFrame(tick)
  }

  $(document).on('click', '#reset-scanner-btn, #reset-scanner-btn-2', resetScanner)
})
