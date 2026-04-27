/**
 * scanner.js — Vendor QR scanner (jQuery)
 *
 * Data flow:
 *   Camera stream → canvas → jsQR decode → verifyCode() POST → handleResult() UI update
 *
 * Activates only when #scanner-page exists in the DOM.
 * jsQR is loaded via CDN <script defer> in the scanner view head.
 */

$(document).on('turbo:load DOMContentLoaded', function () {
  var $page = $('#scanner-page')
  if (!$page.length) return

  var verifyUrl = $page.data('verify-url')
  var csrf      = $('meta[name="csrf-token"]').attr('content')
  var tokenId   = null
  var scanning  = true
  var stream    = null

  var video  = document.getElementById('qr-video')
  var canvas = document.getElementById('qr-canvas')
  var ctx    = canvas.getContext('2d')

  // ── Start camera with high-resolution constraints ────────────────
  if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
    navigator.mediaDevices
      .getUserMedia({
        video: {
          facingMode: 'environment',
          width:  { ideal: 1280 },
          height: { ideal: 720 }
        }
      })
      .then(function (mediaStream) {
        stream = mediaStream
        video.srcObject = mediaStream
        video.play()
        waitForJsQRThenScan()
      })
      .catch(function () {
        $('.ft-scan-hint').text('Camera access denied. Use manual entry below.')
      })
  } else {
    $('.ft-scan-hint').text('Camera not supported on this browser.')
  }

  // ── Wait for jsQR library to load before starting scan loop ──────
  function waitForJsQRThenScan() {
    if (typeof window.jsQR === 'function') {
      requestAnimationFrame(tick)
    } else {
      setTimeout(waitForJsQRThenScan, 100)
    }
  }

  // ── Main scan loop ───────────────────────────────────────────────
  function tick() {
    if (!scanning) return
    if (video.readyState === video.HAVE_ENOUGH_DATA) {
      canvas.height = video.videoHeight
      canvas.width  = video.videoWidth
      ctx.drawImage(video, 0, 0, canvas.width, canvas.height)
      var img  = ctx.getImageData(0, 0, canvas.width, canvas.height)
      var code = window.jsQR(img.data, img.width, img.height, { inversionAttempts: 'attemptBoth' })
      if (code && code.data) {
        scanning = false
        verifyCode(code.data)
        return
      }
    }
    requestAnimationFrame(tick)
  }

  // ── Manual entry ─────────────────────────────────────────────────
  $('#verify-manual-btn').on('click', function () {
    var val = $('#manual-qr').val().trim()
    if (val) { scanning = false; verifyCode(val) }
  })

  $('#manual-qr').on('keypress', function (e) {
    if (e.key === 'Enter') {
      var val = $(this).val().trim()
      if (val) { scanning = false; verifyCode(val) }
    }
  })

  // ── Verify QR code via AJAX POST → ScannerController#verify ─────
  function verifyCode(data) {
    $.ajax({
      url:         verifyUrl,
      method:      'POST',
      contentType: 'application/json',
      headers:     { 'X-CSRF-Token': csrf },
      data:        JSON.stringify({ qr_data: data }),
      success:     handleResult,
      error:       function () {
        showFlashAlert('Error verifying. Please try again.')
        scanning = true
        requestAnimationFrame(tick)
      }
    })
  }

  // ── Handle verify response → show result UI ─────────────────────
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

  // ── Render per-item list + request buttons ───────────────────────
  function renderItems(items, scannedItem) {
    var $items   = $('#token-items').empty()
    var $buttons = $('#request-buttons-container').empty()

    items.forEach(function (item) {
      var highlight = scannedItem && scannedItem.item_code === item.item_code ? 'border border-primary' : ''
      var itemIconLabel = item.icon + ' ' + item.label

      var $itemRow = $('<div>', { class: 'd-flex align-items-center gap-2 p-2 rounded ' + highlight + ' bg-light' })
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
    var $btn   = $(this)
    var itemId = $btn.data('item-id')
    var label  = $btn.data('label')

    setScanRequestButtonLoading($btn)

    $.ajax({
      url:     '/vendor/tokens/' + tokenId + '/send_redemption_request?order_item_id=' + itemId,
      method:  'POST',
      headers: { 'X-CSRF-Token': csrf, 'Content-Type': 'application/json' },
      success: function (data) {
        if (data.success) {
          $btn.replaceWith(createRequestSentAlert(label))
        } else {
          resetScanRequestButton($btn, label)
          showFlashAlert(data.message)
        }
      },
      error: function () {
        resetScanRequestButton($btn, label)
        showFlashAlert('Network error. Please try again.')
      }
    })
  })

  // ── UI helper functions ──────────────────────────────────────────
  function createItemBadge(redeemed) {
    if (redeemed) {
      return $('<span>', { class: 'badge bg-success ms-auto', text: '✅ Redeemed' })
    }
    return $('<span>', { class: 'badge bg-warning text-dark ms-auto', text: '⏳ Pending' })
  }

  function createScanRequestButton(item) {
    var labelText = 'Request: ' + item.icon + ' ' + item.label
    var $button = $('<button>', {
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
    var spinner = $('<span>', { class: 'spinner-border spinner-border-sm me-2', 'aria-hidden': 'true' })
    $btn.prop('disabled', true).empty().append(spinner).append(document.createTextNode('Sending…'))
  }

  function resetScanRequestButton($btn, label) {
    var icon = $('<i>', { class: 'bi bi-send me-2', 'aria-hidden': 'true' })
    $btn.prop('disabled', false).empty().append(icon).append(document.createTextNode('Request: ' + label))
  }

  function createRequestSentAlert(label) {
    var $alert = $('<div>', { class: 'alert alert-success mb-2' })
    $('<i>', { class: 'bi bi-check-circle me-1', 'aria-hidden': 'true' }).appendTo($alert)
    $alert.append(document.createTextNode('Request sent for '))
    $('<strong>', { text: label }).appendTo($alert)
    $alert.append(document.createTextNode(' — waiting for approval'))
    return $alert
  }

  function showFlashAlert(message) {
    var $flash = $('.ft-flash')
    if ($flash.length) $flash.remove()
    var $el = $('<div>', { class: 'ft-flash ft-flash-danger' })
    $('<i>', { class: 'bi bi-exclamation-triangle-fill me-2' }).appendTo($el)
    $el.append(document.createTextNode(message))
    $('<button>', { type: 'button', class: 'ft-flash-close js-flash-close', text: '×' }).appendTo($el)
    $('body').prepend($el)
    setTimeout(function () { $el.fadeOut(500, function () { $(this).remove() }) }, 5000)
  }

  // ── Reset scanner — stops result view, restarts camera scan ──────
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
