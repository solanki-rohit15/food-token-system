/**
 * app_ui.js — General UI interactions (non-GPS, non-scanner, non-dashboard)
 *
 * Handles:
 *   1. Server-rendered flash auto-dismiss (5s)
 *   2. Password toggle + match indicator
 *   3. Meal selection — enable/disable Generate button
 *   4. Token status polling (employee token show page)
 *   5. Admin: radius slider + "use my location" for GPS settings
 *   6. Vendor token show page: per-item redemption request button
 *
 * Flash creation (for AJAX responses) is handled by FT.showFlash in ui.js.
 * This file only handles the auto-dismiss of server-rendered flashes.
 */

$(document).on('turbo:load DOMContentLoaded', function () {

  // ── Server-rendered flash auto-dismiss ────────────────────────────
  // New flashes created via FT.showFlash already have their own timer in ui.js.
  setTimeout(function () {
    $('.ft-flash').fadeOut(500, function () { $(this).remove(); });
  }, 5000);

  $(document).on('click', '.js-flash-close', function () {
    $(this).closest('.ft-flash').remove();
  });

  // ── Password toggle ───────────────────────────────────────────────
  $(document).on('click', '.btn-pw-toggle', function () {
    var $field = $($(this).data('target'));
    var isText = $field.attr('type') === 'text';
    $field.attr('type', isText ? 'password' : 'text');
    $(this).find('i').toggleClass('bi-eye bi-eye-slash');
  });

  // Password match indicator
  $('#pw-confirm').on('input', function () {
    var pw    = $('#pw-field').val();
    var $hint = $('#pw-match-hint');
    if (!$(this).val()) { $hint.text(''); return; }
    if ($(this).val() === pw) {
      $hint.text('✓ Passwords match').removeClass('text-danger').addClass('text-success');
    } else {
      $hint.text('✗ Passwords do not match').removeClass('text-success').addClass('text-danger');
    }
  });

  // ── Meal selection — enable Generate button ───────────────────────
  if ($('#meal-form').length) {
    $(document).on('change', '.ft-meal-checkbox', function () {
      var checked = $('.ft-meal-checkbox:checked');
      var names   = checked.map(function () {
        return $(this).closest('.ft-meal-select-item').find('.ft-meal-select-name').text().trim();
      }).get();

      if (names.length) {
        $('#generate-btn').prop('disabled', false);
        $('#selected-count')
          .text('Selected: ' + names.join(', '))
          .removeClass('text-muted')
          .addClass('text-success fw-semibold');
      } else {
        $('#generate-btn').prop('disabled', true);
        $('#selected-count')
          .text('No meals selected')
          .removeClass('text-success fw-semibold')
          .addClass('text-muted');
      }
    });
  }

  // ── Token status polling (employee token show page) ───────────────
  // Polls /employee/tokens/:id/status every 5s.
  // Reloads if any state changed (new pending request or item redeemed).
  var statusUrl = $('body').data('token-status-url');
  if (statusUrl) {
    var knownState = null;
    setInterval(function () {
      $.getJSON(statusUrl, function (data) {
        var state = JSON.stringify({
          items:   (data.order_items || []).map(function (i) { return i.redeemed; }),
          pending: (data.pending_requests || []).length,
          status:  data.token_status
        });
        if (knownState !== null && knownState !== state) {
          location.reload();
        }
        knownState = state;
      });
    }, 5000);
  }

  // ── Admin: radius slider live label ──────────────────────────────
  $('#radius-slider').on('input', function () {
    $('#radius-display').text('— ' + $(this).val() + 'm');
  });

  // Admin: fill lat/lng from browser GPS
  $(document).on('click', '#use-my-location-btn', function () {
    if (!navigator.geolocation) {
      FT.showFlash('error', 'Geolocation not supported by this browser.');
      return;
    }
    var $btn = $(this);
    FT.showSpinner($btn, 'Getting location…');
    navigator.geolocation.getCurrentPosition(
      function (pos) {
        $('input[name="location_setting[latitude]"]').val(pos.coords.latitude.toFixed(6));
        $('input[name="location_setting[longitude]"]').val(pos.coords.longitude.toFixed(6));
        FT.resetButton($btn);
        FT.showFlash('success', 'Location filled in. Save to apply.');
      },
      function (err) {
        FT.resetButton($btn);
        FT.showFlash('error', 'Could not get location: ' + err.message);
      },
      { enableHighAccuracy: true, timeout: 10000 }
    );
  });

  // ── Vendor token SHOW page: per-item redemption request ──────────
  // (Scanner page redemption is handled in scanner.js)
  $(document).on('click', '.send-redemption-btn', function () {
    var $btn     = $(this);
    var itemId   = $btn.data('item-id');
    var label    = $btn.data('label');
    var tokenUrl = $btn.data('url');

    FT.showSpinner($btn, 'Sending…');

    FT.apiRequest({
      url:    tokenUrl + '?order_item_id=' + itemId,
      method: 'POST'
    })
    .then(function (data) {
      if (data.success) {
        var $alert = $('<div>', { class: 'alert alert-warning d-flex align-items-center gap-2 mb-2' });
        $('<i>', { class: 'bi bi-hourglass-split' }).appendTo($alert);
        $alert.append(document.createTextNode('Waiting for employee to approve '));
        $('<strong>', { text: label }).appendTo($alert);
        $btn.replaceWith($alert);
        FT.showFlash('success', data.message || 'Request sent.');
      } else {
        FT.resetButton($btn);
        FT.showFlash('error', data.message || 'Action failed.');
      }
    })
    .catch(function (err) {
      FT.resetButton($btn);
      FT.handleError(err);
    });
  });

  // ── Generic AJAX Form Handler ──────────────────────────────────────
  $(document).on('submit', '.js-fetch-form', function (e) {
    e.preventDefault();
    var form = this;
    var $form = $(form);
    var $btn = $form.find('button[type="submit"], input[type="submit"]').first();
    var url = $form.attr('action');
    var method = ($form.find('input[name="_method"]').val() || $form.attr('method')).toUpperCase();
    
    // Build a properly-nested body from bracket-notation field names
    // e.g. meal_settings[morning_tea][start_time] → { meal_settings: { morning_tea: { start_time: ... } } }
    var body = {};
    $form.serializeArray().forEach(function (item) {
      var keys = item.name.replace(/\]/g, '').split('[');
      var obj = body;
      for (var i = 0; i < keys.length - 1; i++) {
        var k = keys[i];
        if (!obj[k] || typeof obj[k] !== 'object') obj[k] = {};
        obj = obj[k];
      }
      var lastKey = keys[keys.length - 1];
      if (lastKey.endsWith('[]') || item.name.endsWith('[]')) {
        var arrKey = lastKey.replace('[]', '');
        obj[arrKey] = obj[arrKey] || [];
        obj[arrKey].push(item.value);
      } else {
        obj[lastKey] = item.value;
      }
    });

    FT.showSpinner($btn);

    FT.apiRequest({ url: url, method: method, body: body })
      .then(function (data) {
        FT.resetButton($btn);
        if (data.success) {
          FT.showFlash('success', data.message || 'Success.');
          
          if ($form.hasClass('js-user-toggle-form')) {
            var userId = $form.data('user-id');
            var $status = $('#user_status_' + userId);
            if (data.active) {
              $status.empty().append($('<span>', { class: 'badge bg-success', text: 'Active' }));
              $btn.removeClass('btn-outline-success').addClass('btn-outline-warning').text('Deactivate');
            } else {
              $status.empty().append($('<span>', { class: 'badge bg-secondary', text: 'Inactive' }));
              $btn.removeClass('btn-outline-warning').addClass('btn-outline-success').text('Activate');
            }
          }

          if ($form.hasClass('js-user-show-toggle-form')) {
            var $badge = $('#user_show_status_badge_' + $form.data('user-id'));
            if (data.active) {
              $badge.empty().append($('<span>', { class: 'badge bg-success', text: 'Active' }));
              $btn.removeClass('btn-outline-success').addClass('btn-outline-warning').text('Deactivate');
            } else {
              $badge.empty().append($('<span>', { class: 'badge bg-secondary', text: 'Inactive' }));
              $btn.removeClass('btn-outline-warning').addClass('btn-outline-success').text('Activate');
            }
          }
          
          if ($form.hasClass('js-user-delete-form')) {
            var userId = $form.data('user-id');
            $('#user_row_' + userId).fadeOut(400, function() { $(this).remove(); });
          }

          // Redemption approve — remove pending card, reload after 1s
          if ($form.hasClass('js-redemption-approve-form') || $form.hasClass('js-redemption-reject-form')) {
            if (data.request_id) {
              $('#pending_req_' + data.request_id).fadeOut(400, function() { $(this).remove(); });
            }
            setTimeout(function() { location.reload(); }, 1000);
          }
          
          if ($form.hasClass('js-reload-on-success')) {
            setTimeout(function() { location.reload(); }, 1000);
          }
        } else {
          FT.showFlash('error', data.message || 'Action failed.');
        }
      })
      .catch(function (err) {
        FT.resetButton($btn);
        FT.handleError(err);
      });
  });

  // ── View User Modal Handler ────────────────────────────────────────
  $(document).on('click', '.js-user-view-btn', function (e) {
    e.preventDefault();
    var $btn = $(this);
    var url = $btn.attr('href');
    
    // Add .json extension if missing to ensure we request JSON format
    if (url.indexOf('.json') === -1) {
      url = url + '.json';
    }

    FT.showSpinner($btn, '...');

    FT.apiRequest({ url: url, method: 'GET' })
      .then(function (data) {
        FT.resetButton($btn, 'View');
        
        // Remove old modal if exists
        var existingModal = document.getElementById('userAjaxModal');
        if (existingModal) {
          bootstrap.Modal.getInstance(existingModal)?.dispose();
          existingModal.remove();
        }

        // Build modal using jQuery to avoid innerHTML
        var $modal = $('<div>', { class: 'modal fade', id: 'userAjaxModal', tabindex: '-1', 'aria-hidden': 'true' });
        var $dialog = $('<div>', { class: 'modal-dialog modal-lg' }).appendTo($modal);
        var $content = $('<div>', { class: 'modal-content' }).appendTo($dialog);

        // Header
        var $header = $('<div>', { class: 'modal-header' }).appendTo($content);
        var $title = $('<h5>', { class: 'modal-title d-flex align-items-center gap-2' }).appendTo($header);
        $title.append(document.createTextNode(data.user.name + ' '));
        
        var badgeClass = 'bg-secondary';
        if (data.user.role === 'admin') badgeClass = 'bg-dark';
        if (data.user.role === 'employee') badgeClass = 'bg-primary';
        if (data.user.role === 'vendor') badgeClass = 'bg-info text-dark';
        
        var roleText = data.user.role.charAt(0).toUpperCase() + data.user.role.slice(1);
        $('<span>', { class: 'badge ' + badgeClass, text: roleText }).appendTo($title);
        
        var statusBadgeClass = data.active ? 'bg-success' : 'bg-secondary';
        var statusText = data.active ? 'Active' : 'Inactive';
        $('<span>', { class: 'badge ' + statusBadgeClass, text: statusText }).appendTo($title);

        $('<button>', { type: 'button', class: 'btn-close', 'data-bs-dismiss': 'modal', 'aria-label': 'Close' }).appendTo($header);

        // Body
        var $body = $('<div>', { class: 'modal-body bg-light' }).appendTo($content);
        var $row = $('<div>', { class: 'row g-3' }).appendTo($body);

        // Left Col (Profile)
        var $colLeft = $('<div>', { class: 'col-md-4' }).appendTo($row);
        var $cardProfile = $('<div>', { class: 'card ft-card h-100' }).appendTo($colLeft);
        var $cardBodyProfile = $('<div>', { class: 'card-body text-center' }).appendTo($cardProfile);
        
        $('<div>', { class: 'ft-avatar-xl mx-auto mb-3', text: data.initials }).appendTo($cardBodyProfile);
        $('<h5>', { class: 'fw-bold mb-0', text: data.user.name }).appendTo($cardBodyProfile);
        $('<p>', { class: 'text-muted small mb-2', text: data.user.email }).appendTo($cardBodyProfile);
        
        if (data.user.phone) {
          var $phoneP = $('<p>', { class: 'text-muted small mb-2' }).appendTo($cardBodyProfile);
          $('<i>', { class: 'bi bi-phone me-1' }).appendTo($phoneP);
          $phoneP.append(document.createTextNode(data.user.phone));
        }
        
        if (data.employee_id) {
          var $deptP = $('<p>', { class: 'text-muted small mb-0' }).appendTo($cardBodyProfile);
          $('<i>', { class: 'bi bi-person-badge me-1' }).appendTo($deptP);
          $deptP.append(document.createTextNode('ID: '));
          $('<span>', { class: 'font-monospace', text: data.employee_id }).appendTo($deptP);
        }

        // Right Col (Tokens)
        var $colRight = $('<div>', { class: 'col-md-8' }).appendTo($row);
        var $cardTokens = $('<div>', { class: 'card ft-card h-100' }).appendTo($colRight);
        var $cardHeaderTokens = $('<div>', { class: 'card-header bg-white d-flex justify-content-between align-items-center' }).appendTo($cardTokens);
        $('<h5>', { class: 'mb-0 fw-bold', text: 'Recent Tokens' }).appendTo($cardHeaderTokens);
        $('<span>', { class: 'badge bg-secondary', text: data.tokens.length }).appendTo($cardHeaderTokens);
        
        var $tableResp = $('<div>', { class: 'table-responsive' }).appendTo($cardTokens);
        var $table = $('<table>', { class: 'table ft-table align-middle mb-0' }).appendTo($tableResp);
        var $thead = $('<thead>', { class: 'table-light' }).appendTo($table);
        var $trHead = $('<tr>').appendTo($thead);
        ['Date', 'Items', 'Token', 'Status'].forEach(function(th) {
          $('<th>', { text: th }).appendTo($trHead);
        });
        
        var $tbody = $('<tbody>').appendTo($table);
        if (data.tokens.length === 0) {
          var $emptyTr = $('<tr>').appendTo($tbody);
          $('<td>', { colspan: 4, class: 'text-center text-muted py-3', text: 'No tokens yet.' }).appendTo($emptyTr);
        } else {
          data.tokens.forEach(function(t) {
            var $tr = $('<tr>').appendTo($tbody);
            $('<td>', { class: 'small text-muted', text: t.date }).appendTo($tr);
            $('<td>', { class: 'small', text: t.items }).appendTo($tr);
            
            var $tdToken = $('<td>').appendTo($tr);
            $('<span>', { class: 'badge bg-light border text-dark font-monospace', text: t.token_number }).appendTo($tdToken);
            
            var $tdStatus = $('<td>').appendTo($tr);
            if (t.status === 'redeemed') {
              $('<span>', { class: 'badge bg-success', text: '✅ Redeemed' }).appendTo($tdStatus);
            } else if (t.status === 'expired') {
              $('<span>', { class: 'badge bg-danger', text: '⏰ Expired' }).appendTo($tdStatus);
            } else if (t.status === 'active') {
              $('<span>', { class: 'badge bg-warning text-dark', text: '⏳ Active' }).appendTo($tdStatus);
            } else {
              $('<span>', { class: 'badge bg-secondary', text: t.status }).appendTo($tdStatus);
            }
          });
        }

        // Footer
        var $footer = $('<div>', { class: 'modal-footer' }).appendTo($content);
        $('<button>', { type: 'button', class: 'btn btn-outline-secondary', 'data-bs-dismiss': 'modal', text: 'Close' }).appendTo($footer);
        $('<a>', { href: '/admin/users/' + data.user.id + '/edit', class: 'btn btn-outline-primary', text: 'Edit User' }).appendTo($footer);

        $('body').append($modal);
        var myModal = new bootstrap.Modal($modal[0]);
        myModal.show();
      })
      .catch(function (err) {
        FT.resetButton($btn, 'View');
        FT.handleError(err);
      });
  });

  // ── Search & Filter Users ──────────────────────────────────────────
  $(document).on('submit', '.js-users-search-form', function (e) {
    e.preventDefault();
    var $form = $(this);
    var url = $form.attr('action') + '?' + $form.serialize();
    var $btn = $form.find('button[type="submit"]');

    FT.showSpinner($btn, '...');

    $.ajax({
      url: url,
      method: 'GET',
      headers: { 'X-Requested-With': 'XMLHttpRequest' },
      success: function(html) {
        // Restore from saved original HTML — avoids passing raw HTML strings
        FT.resetButton($btn);
        var newContent = $(html).find('#users-list-container').html();
        if (newContent) {
          $('#users-list-container').html(newContent);
        }
      },
      error: function() {
        FT.resetButton($btn);
        FT.showFlash('error', 'Search failed.');
      }
    });
  });

  $(document).on('click', '.js-users-clear-btn', function (e) {
    e.preventDefault();
    var $form = $('.js-users-search-form');
    $form[0].reset();
    $form.find('input[type="text"]').val('');
    $form.find('select').val('');
    $form.trigger('submit');
  });

  // ── Add User Modal ─────────────────────────────────────────────────
  $(document).on('click', '.js-user-add-btn', function (e) {
    e.preventDefault();
    var existingModal = document.getElementById('userAddModal');
    if (existingModal) {
      bootstrap.Modal.getInstance(existingModal)?.dispose();
      existingModal.remove();
    }

    var $modal = $('<div>', { class: 'modal fade', id: 'userAddModal', tabindex: '-1', 'aria-hidden': 'true' });
    var $dialog = $('<div>', { class: 'modal-dialog' }).appendTo($modal);
    var $content = $('<div>', { class: 'modal-content' }).appendTo($dialog);

    var $header = $('<div>', { class: 'modal-header' }).appendTo($content);
    $('<h5>', { class: 'modal-title fw-bold', text: 'Add New User' }).appendTo($header);
    $('<button>', { type: 'button', class: 'btn-close', 'data-bs-dismiss': 'modal' }).appendTo($header);

    var $body = $('<div>', { class: 'modal-body' }).appendTo($content);
    
    // Form
    var $form = $('<form>', { id: 'add-user-form' }).appendTo($body);
    
    var $mb1 = $('<div>', { class: 'mb-3' }).appendTo($form);
    $('<label>', { class: 'form-label', text: 'Name' }).appendTo($mb1);
    $('<input>', { type: 'text', name: 'user[name]', class: 'form-control', required: true }).appendTo($mb1);

    var $mb2 = $('<div>', { class: 'mb-3' }).appendTo($form);
    $('<label>', { class: 'form-label', text: 'Email' }).appendTo($mb2);
    $('<input>', { type: 'email', name: 'user[email]', class: 'form-control', required: true }).appendTo($mb2);

    var $mb3 = $('<div>', { class: 'mb-3' }).appendTo($form);
    $('<label>', { class: 'form-label', text: 'Phone' }).appendTo($mb3);
    $('<input>', { type: 'text', name: 'user[phone]', class: 'form-control' }).appendTo($mb3);

    var $mb4 = $('<div>', { class: 'mb-3' }).appendTo($form);
    $('<label>', { class: 'form-label', text: 'Role' }).appendTo($mb4);
    var $select = $('<select>', { name: 'user[role]', class: 'form-select' }).appendTo($mb4);
    $('<option>', { value: 'employee', text: 'Employee' }).appendTo($select);
    $('<option>', { value: 'vendor', text: 'Vendor' }).appendTo($select);

    var $mb5 = $('<div>', { class: 'form-check mb-3' }).appendTo($form);
    $('<input>', { type: 'checkbox', class: 'form-check-input', id: 'user_active_chk', checked: true }).appendTo($mb5);
    $('<label>', { class: 'form-check-label', for: 'user_active_chk', text: 'Active Account' }).appendTo($mb5);

    var $footer = $('<div>', { class: 'modal-footer' }).appendTo($content);
    $('<button>', { type: 'button', class: 'btn btn-outline-secondary', 'data-bs-dismiss': 'modal', text: 'Cancel' }).appendTo($footer);
    var $submitBtn = $('<button>', { type: 'submit', class: 'btn ft-btn-primary', text: 'Save User' }).appendTo($footer);
    
    $submitBtn.click(function(e) {
      e.preventDefault();
      $form.submit();
    });

    $form.on('submit', function(e) {
      e.preventDefault();
      FT.showSpinner($submitBtn, 'Saving...');
      
      var body = {
        user: {
          name: $form.find('input[name="user[name]"]').val(),
          email: $form.find('input[name="user[email]"]').val(),
          phone: $form.find('input[name="user[phone]"]').val(),
          role: $form.find('select[name="user[role]"]').val(),
          active: $form.find('#user_active_chk').is(':checked') ? 1 : 0
        }
      };

      FT.apiRequest({ url: '/admin/users.json', method: 'POST', body: body })
        .then(function(res) {
          FT.resetButton($submitBtn, 'Save User');
          if(res.success) {
            bootstrap.Modal.getInstance($modal[0]).hide();
            FT.showFlash('success', res.message);
            $('.js-users-search-form').trigger('submit');
          } else {
            FT.showFlash('error', res.message);
          }
        })
        .catch(function(err) {
          FT.resetButton($submitBtn, 'Save User');
          FT.handleError(err);
        });
    });

    $('body').append($modal);
    var myModal = new bootstrap.Modal($modal[0]);
    myModal.show();
  });

  // ── Global SPA Navigation (No-Reload) ─────────────────────────────
  $(document).on('click', '.js-pjax-link', function (e) {
    e.preventDefault();
    var url = $(this).attr('href');
    var $btn = $(this);
    var oldHtml = $btn.html();
    
    FT.showSpinner($btn, '...');

    $.ajax({
      url: url,
      method: 'GET',
      headers: { 'X-Requested-With': 'XMLHttpRequest' },
      success: function(html) {
        var newMain = $('<div>').html(html).find('main').html();
        if (newMain) {
          $('main').html(newMain);
          window.history.pushState({ path: url }, '', url);
        } else {
          location.href = url; // Fallback
        }
      },
      error: function() {
        FT.resetButton($btn, oldHtml);
        FT.showFlash('error', 'Failed to load page.');
      }
    });
  });

  $(document).on('submit', '.js-pjax-form', function (e) {
    e.preventDefault();
    var $form = $(this);
    var url = $form.attr('action') + '?' + $form.serialize();
    var $btn = $form.find('button[type="submit"]');
    var oldHtml = $btn.html();
    
    if ($btn.length) {
      FT.showSpinner($btn, '...');
    } else {
      $('main').css('opacity', '0.6');
    }

    $.ajax({
      url: url,
      method: 'GET',
      headers: { 'X-Requested-With': 'XMLHttpRequest' },
      success: function(html) {
        if ($btn.length) FT.resetButton($btn, oldHtml);
        $('main').css('opacity', '1');
        var newMain = $('<div>').html(html).find('main').html();
        if (newMain) {
          $('main').html(newMain);
          window.history.pushState({ path: url }, '', url);
        }
      },
      error: function() {
        if ($btn.length) FT.resetButton($btn, oldHtml);
        $('main').css('opacity', '1');
        FT.showFlash('error', 'Failed to filter.');
      }
    });
  });

  window.addEventListener('popstate', function(event) {
    location.reload();
  });

});
