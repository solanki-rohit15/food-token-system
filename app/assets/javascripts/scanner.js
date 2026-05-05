/**
 * scanner.js — Vendor QR scanner
 * Handles camera stream, jsQR decode, verify API call, result rendering.
 */
(function () {
  'use strict';

  var verifyUrl = null;
  var tokenId   = null;
  var scanning  = true;
  var stream    = null;
  var video, canvas, ctx;
  var knownState = null;
  var pollInterval = null;

  // Init
  function init() {
    var $page = $('#scanner-page');
    if (!$page.length) return;

    verifyUrl = $page.data('verify-url');
    video     = document.getElementById('qr-video');
    canvas    = document.getElementById('qr-canvas');
    ctx       = canvas ? canvas.getContext('2d') : null;

    bindEvents();
    startCamera();

    var prefilled = $page.data('prefilled-result');
    if (prefilled) {
      scanning = false;
      handleResult(prefilled);
    }
  }

  // Camera
  function startCamera() {
    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
      updateHint('Camera not supported on this browser.');
      return;
    }

    navigator.mediaDevices.getUserMedia({
      video: { facingMode: 'environment', width: { ideal: 1280 }, height: { ideal: 720 } }
    })
    .then(function (mediaStream) {
      stream  = mediaStream;
      video.srcObject = mediaStream;
      video.play();
      waitForJsQR();
    })
    .catch(function () {
      updateHint('Camera access denied. Use manual entry below.');
    });
  }

  function waitForJsQR() {
    if (typeof window.jsQR === 'function') {
      requestAnimationFrame(tick);
    } else {
      setTimeout(waitForJsQR, 100);
    }
  }

  // Scan loop
  function tick() {
    if (!scanning) return;
    if (video && video.readyState === video.HAVE_ENOUGH_DATA) {
      canvas.height = video.videoHeight;
      canvas.width  = video.videoWidth;
      ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
      var imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
      var code = window.jsQR(imageData.data, imageData.width, imageData.height, {
        inversionAttempts: 'attemptBoth'
      });
      if (code && code.data) {
        scanning = false;
        verifyCode(code.data);
        return;
      }
    }
    requestAnimationFrame(tick);
  }

  function bindEvents() {

    $(document).on('click', '#reset-scanner-btn, #reset-scanner-btn-2', resetScanner);

    $(document).on('click', '.send-scan-req', onSendRedemptionRequest);
  }

  // Verify via API
  function verifyCode(data) {
    FT.apiRequest({
      url:    verifyUrl,
      method: 'POST',
      body:   { qr_data: String(data).trim() }
    })
    .then(handleResult)
    .catch(function (err) {
      // Show invalid panel with server message
      handleResult({ valid: false, message: err.message || 'Error verifying. Please try again.' });
    });
  }

  // Handle verify response
  function handleResult(result) {
    $('#scan-result').removeClass('d-none');
    $('#camera-view').addClass('d-none');

    if (result.valid) {
      tokenId = result.token_id;
      showValidResult(result);
    } else {
      showInvalidResult(result);
    }
  }

  function showValidResult(result) {
    startPolling();
    $('#result-valid').removeClass('d-none');
    $('#result-invalid').addClass('d-none');

    // Employee info — using textContent via jQuery .text() to prevent XSS
    $('#emp-initials').text(result.employee.initials);
    $('#emp-name').text(result.employee.name);
    $('#emp-email').text(result.employee.email);
    $('#emp-dept').text(result.employee.department || '');
    $('#token-id-disp').text(result.token_number);
    $('#token-expiry').text(result.expires_at);

    if (result.scanned_item) {
      $('#scanned-item-info').removeClass('d-none');
      $('#scanned-item-badge').text(result.scanned_item.category);
    } else {
      $('#scanned-item-info').addClass('d-none');
    }

    renderItems(result.items, result.scanned_item);
  }

  function showInvalidResult(result) {
    $('#result-invalid').removeClass('d-none');
    $('#result-valid').addClass('d-none');
    $('#invalid-message').text(result.message || 'This code is not valid.');
  }

  // Render item list + request buttons
  function renderItems(items, scannedItem) {
    var $items   = $('#token-items').empty();
    var $buttons = $('#request-buttons-container').empty();
    var allRedeemed = true;

    (items || []).forEach(function (item) {
      var isHighlighted = scannedItem && scannedItem.item_code === item.item_code;
      var $row = buildItemRow(item, isHighlighted);
      $items.append($row);

      if (!item.redeemed) {
        allRedeemed = false;
        if (item.order_item_id) {
          var $btn = buildRequestButton(item);
          $buttons.append($btn);
          
          // Automatically send the redemption request for the specifically scanned item
          if (isHighlighted) {
            setTimeout(function() { $btn.click(); }, 300);
          }
        }
      }
    });

    if (allRedeemed && items && items.length > 0) {
      $buttons.append(
        $('<div>', { class: 'alert alert-success mb-0' })
          .append($('<i>', { class: 'bi bi-check-circle-fill me-2' }))
          .append(document.createTextNode('All items have been redeemed.'))
      );
    }
  }

  function buildItemRow(item, highlighted) {
    var $row = $('<div>', {
      class: 'd-flex align-items-center gap-2 p-2 rounded bg-light' + (highlighted ? ' border border-primary' : '')
    });
    $('<span>').text(item.icon + ' ' + item.label).appendTo($row);
    buildStatusBadge(item.redeemed, item.redeemed_at).appendTo($row);
    return $row;
  }

  function buildStatusBadge(redeemed, redeemedAt) {
    if (redeemed) {
      return $('<span>', {
        class: 'badge bg-success ms-auto',
        text:  '✅ Redeemed' + (redeemedAt ? ' ' + redeemedAt : '')
      });
    }
    return $('<span>', { class: 'badge bg-warning text-dark ms-auto', text: '⏳ Pending' });
  }

  function buildRequestButton(item) {
    var $btn = $('<button>', {
      type:  'button',
      class: 'btn ft-btn-primary w-100 mb-2 send-scan-req'
    })
    .attr('data-item-id',    item.order_item_id)
    .attr('data-item-label', item.label);

    $('<i>', { class: 'bi bi-send me-2', 'aria-hidden': 'true' }).appendTo($btn);
    $btn.append(document.createTextNode('Request: ' + item.icon + ' ' + item.label));
    return $btn;
  }

  // Send redemption request
  function onSendRedemptionRequest() {
    var $btn   = $(this);
    var itemId = $btn.data('item-id');
    var label  = $btn.data('item-label');

    if (!tokenId) { FT.showFlash('error', 'Token not loaded. Please scan again.'); return; }

    FT.showSpinner($btn, 'Sending…');

    FT.apiRequest({
      url:    '/vendor/tokens/' + tokenId + '/send_redemption_request',
      method: 'POST',
      body:   { order_item_id: itemId }
    })
    .then(function (data) {
      if (data.success) {
        $btn.replaceWith(buildSentAlert(label));
        FT.showFlash('success', data.message || 'Request sent.');
      } else {
        FT.resetButton($btn);
        FT.showFlash('error', data.message || 'Could not send request.');
      }
    })
    .catch(function (err) {
      FT.resetButton($btn);
      FT.handleError(err);
    });
  }

  function buildSentAlert(label) {
    var $alert = $('<div>', { class: 'alert alert-success mb-2 d-flex align-items-center gap-2' });
    $('<i>', { class: 'bi bi-hourglass-split' }).appendTo($alert);
    $alert.append(document.createTextNode('Request sent for '));
    $('<strong>', { text: label }).appendTo($alert);
    $alert.append(document.createTextNode(' — waiting for employee approval'));
    return $alert;
  }

  // Reset
  function resetScanner() {
    stopPolling();
    tokenId  = null;
    scanning = true;
    $('#scan-result').addClass('d-none');
    $('#camera-view').removeClass('d-none');
    $('#result-valid, #result-invalid').addClass('d-none');
    requestAnimationFrame(tick);
  }

  // Utility
  function updateHint(text) {
    $('.ft-scan-hint').text(text);
  }

  function startPolling() {
    stopPolling();
    knownState = null;
    pollInterval = setInterval(function() {
      if (!tokenId) return;
      $.getJSON('/vendor/tokens/' + tokenId + '/status', function(data) {
        var state = JSON.stringify({
          items:   (data.order_items || []).map(function (i) { return i.redeemed; }),
          status:  data.token_status
        });
        if (knownState !== null && knownState !== state) {
          // State changed! Re-verify to re-render the whole result block
          verifyCode('{"id":' + tokenId + '}');
        }
        knownState = state;
      });
    }, 4000);
  }

  function stopPolling() {
    if (pollInterval) {
      clearInterval(pollInterval);
      pollInterval = null;
    }
  }

  document.addEventListener('turbo:load',       init);
  document.addEventListener('DOMContentLoaded', init);

})();
