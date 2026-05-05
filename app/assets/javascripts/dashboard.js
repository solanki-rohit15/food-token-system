/**
 * dashboard.js — Vendor dashboard AJAX filters
 *
 * Handles: daily/monthly toggle, date picker, "Today" button, search, filter
 *
 * All filter changes make an AJAX request to the current URL with
 * Accept: application/json. The server returns data and we re-render
 * the relevant sections without a page reload.
 *
 * Activated only when #vendor-dashboard exists in the DOM.
 */
(function () {
  'use strict';

  function init() {
    var $dash = $('#vendor-dashboard');
    if ($dash.length) {
      // Delegate all filter interactions to the dashboard wrapper
      $(document).off('click', '#btn-view-daily').on('click', '#btn-view-daily',   switchToDaily);
      $(document).off('click', '#btn-view-monthly').on('click', '#btn-view-monthly', switchToMonthly);
      $(document).off('click', '#btn-today').on('click', '#btn-today',        goToday);
      $(document).off('change', '#date-picker').on('change','#date-picker',      onDateChange);
      $(document).off('change', '#month-picker').on('change','#month-picker',     onMonthChange);
    }

    var $tokens = $('#vendor-tokens-page');
    if ($tokens.length) {
      // Token list page filters
      $(document).off('click', '#btn-filter-tokens').on('click', '#btn-filter-tokens', applyTokenFilter);
      $(document).off('click', '#btn-today-tokens').on('click', '#btn-today-tokens',  resetTokenFilter);
      $(document).off('change', '#token-status-select').on('change','#token-status-select', applyTokenFilter);
    }
  }

  // ── Current state ─────────────────────────────────────────────────
  var state = {
    view:  $('meta[name="dashboard-view"]').attr('content')  || 'daily',
    date:  $('meta[name="dashboard-date"]').attr('content')  || today(),
    month: $('meta[name="dashboard-month"]').attr('content') || currentMonth()
  };

  function today() {
    var d = new Date();
    return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0');
  }

  function currentMonth() {
    var d = new Date();
    return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0');
  }

  // ── View toggles ──────────────────────────────────────────────────
  function switchToDaily(e) {
    e.preventDefault();
    state.view = 'daily';
    fetchDashboard();
  }

  function switchToMonthly(e) {
    e.preventDefault();
    state.view = 'monthly';
    fetchDashboard();
  }

  function goToday(e) {
    e.preventDefault();
    state.view = 'daily';
    state.date = today();
    $('#date-picker').val(state.date);
    fetchDashboard();
  }

  function onDateChange() {
    state.view = 'daily';
    state.date = $(this).val() || today();
    fetchDashboard();
  }

  function onMonthChange() {
    state.view = 'monthly';
    state.month = $(this).val() || currentMonth();
    fetchDashboard();
  }

  // ── Fetch dashboard data ──────────────────────────────────────────
  function fetchDashboard() {
    showDashboardLoading(true);

    var params = { view: state.view };
    if (state.view === 'monthly') {
      params.month = state.month;
    } else {
      params.date = state.date;
    }

    FT.apiRequest({ url: '/vendor', method: 'GET', params: params })
      .then(function (data) {
        if (data.view_mode === 'monthly') {
          renderMonthly(data);
        } else {
          renderDaily(data);
        }
        updateViewToggleBtns(data.view_mode);
        updateDateControls(data);
      })
      .catch(FT.handleError)
      .finally(function () {
        showDashboardLoading(false);
      });
  }

  // ── DOM renderers ─────────────────────────────────────────────────
  function renderDaily(data) {
    // Update page subtitle
    $('#dashboard-subtitle').text(data.date_label);

    // Stats
    if (data.stats) {
      $('#stat-total').text(data.stats.total_selected);
      $('#stat-redeemed').text(data.stats.redeemed);
      $('#stat-unredeemed').text(data.stats.unredeemed);
      $('#stat-amount').text(data.stats.total_amount_formatted);
    }

    // Meal summary table
    var $mealBody = $('#meal-summary-tbody').empty();
    var grandTotal = 0;
    (data.meal_summary || []).forEach(function (m) {
      if (m.count === 0) return;
      grandTotal += m.amount;
      var $tr = $('<tr>');
      var $tdIconLabel = $('<td>');
      $('<span>').text(m.icon + ' ' + m.label).appendTo($tdIconLabel);
      $tdIconLabel.appendTo($tr);
      $('<td>', { class: 'text-center fw-bold', text: m.count }).appendTo($tr);
      $('<td>', { class: 'text-end text-muted', text: m.price_formatted }).appendTo($tr);
      $('<td>', { class: 'text-end fw-bold', text: m.amount_formatted }).appendTo($tr);
      $mealBody.append($tr);
    });
    // Update grand total footer
    $('#meal-summary-grand-total').text(formatCurrency(grandTotal));

    // Show/hide sections
    toggleSection('#meal-summary-section',  (data.meal_summary || []).some(function (m) { return m.count > 0; }));

    // Recent scans
    var $scanBody = $('#recent-scans-tbody').empty();
    (data.recent_scans || []).forEach(function (t) {
      var $tr = $('<tr>');
      
      var $tdEmp = $('<td>');
      var $empFlex = $('<div>', { class: 'd-flex align-items-center gap-2' }).appendTo($tdEmp);
      $('<div>', { class: 'ft-avatar-sm', text: t.employee_initials }).appendTo($empFlex);
      var $empInfo = $('<div>').appendTo($empFlex);
      $('<div>', { class: 'fw-semibold small', text: t.employee_name }).appendTo($empInfo);
      if (t.employee_dept) {
        $('<div>', { class: 'text-muted', style: 'font-size:11px', text: t.employee_dept }).appendTo($empInfo);
      }
      $tdEmp.appendTo($tr);

      $('<td>', { class: 'small', text: t.categories }).appendTo($tr);
      var $tdToken = $('<td>');
      $('<span>', { class: 'badge bg-success-subtle text-success border border-success-subtle font-monospace', text: t.token_number }).appendTo($tdToken);
      $tdToken.appendTo($tr);
      $('<td>', { class: 'small text-muted', text: t.redeemed_at || '' }).appendTo($tr);
      
      $scanBody.append($tr);
    });
    toggleSection('#recent-scans-section', (data.recent_scans || []).length > 0);
    toggleSection('#empty-state', (data.stats && data.stats.total_selected === 0));
    toggleSection('#daily-view', true);
    toggleSection('#monthly-view', false);
  }

  function renderMonthly(data) {
    $('#dashboard-subtitle').text(data.month_label + ' — Monthly Report');

    // Monthly summary table
    var $body = $('#monthly-summary-tbody').empty();
    (data.monthly_summary || []).forEach(function (m) {
      if (m.count === 0) return;
      var $tr = $('<tr>');
      var $tdIconLabel = $('<td>');
      $('<span>').text(m.icon + ' ' + m.label).appendTo($tdIconLabel);
      $tdIconLabel.appendTo($tr);
      $('<td>', { class: 'text-center fw-bold', text: m.count }).appendTo($tr);
      $('<td>', { class: 'text-end text-muted', text: m.price_formatted }).appendTo($tr);
      $('<td>', { class: 'text-end fw-bold', text: m.amount_formatted }).appendTo($tr);
      $body.append($tr);
    });
    var grandTotal = (data.monthly_summary || []).reduce(function (s, m) { return s + m.amount; }, 0);
    $('#monthly-grand-total').text(formatCurrency(grandTotal));

    // Daily breakdown table
    var $daily = $('#daily-breakdown-tbody').empty();
    (data.daily_breakdown || []).forEach(function (day) {
      if (day.total === 0) return;
      var $tr = $('<tr>');
      $('<td>', { class: 'small fw-semibold', text: day.date_label }).appendTo($tr);
      
      // Category counts — order must match header
      ['morning_tea', 'breakfast', 'lunch', 'evening_tea'].forEach(function (cat) {
        var s = day.summary[cat];
        $('<td>', { class: 'text-center small', text: (s ? s.count : 0) }).appendTo($tr);
      });
      $('<td>', { class: 'text-end fw-bold', text: day.total_formatted }).appendTo($tr);
      $daily.append($tr);
    });

    toggleSection('#daily-view', false);
    toggleSection('#monthly-view', true);
  }

  function updateViewToggleBtns(viewMode) {
    if (viewMode === 'monthly') {
      $('#btn-view-daily').removeClass('btn-primary').addClass('btn-outline-secondary');
      $('#btn-view-monthly').removeClass('btn-outline-secondary').addClass('btn-primary');
      $('#date-controls').addClass('d-none');
      $('#month-controls').removeClass('d-none');
    } else {
      $('#btn-view-monthly').removeClass('btn-primary').addClass('btn-outline-secondary');
      $('#btn-view-daily').removeClass('btn-outline-secondary').addClass('btn-primary');
      $('#month-controls').addClass('d-none');
      $('#date-controls').removeClass('d-none');
    }
  }

  function updateDateControls(data) {
    if (data.view_mode === 'daily' && data.date) {
      $('#date-picker').val(data.date);
    } else if (data.view_mode === 'monthly' && data.month) {
      $('#month-picker').val(data.month);
    }
  }

  // ── Token list filters (vendor/tokens page) ───────────────────────
  function applyTokenFilter(e) {
    if (e) e.preventDefault();

    var params = {
      date:   $('#token-date-picker').val() || today(),
      status: $('#token-status-select').val() || '',
      search: $('#token-search').val() || ''
    };

    FT.apiRequest({ url: '/vendor/tokens', method: 'GET', params: params })
      .then(renderTokenList)
      .catch(FT.handleError);
  }

  function resetTokenFilter(e) {
    e.preventDefault();
    $('#token-date-picker').val(today());
    $('#token-status-select').val('');
    $('#token-search').val('');
    applyTokenFilter();
  }

  function renderTokenList(data) {
    $('#tokens-date-label').text(data.date_label + ' • ' + data.total + ' records');

    var $tbody = $('#tokens-tbody').empty();
    if (!data.tokens || !data.tokens.length) {
      var $emptyTr = $('<tr>');
      var $emptyTd = $('<td>', { colspan: 6, class: 'text-center text-muted py-4' }).appendTo($emptyTr);
      $('<div>', { class: 'fs-1', text: '🎫' }).appendTo($emptyTd);
      $emptyTd.append(document.createTextNode('No tokens found.'));
      $tbody.append($emptyTr);
      return;
    }

    data.tokens.forEach(function (t) {
      var $tr = $('<tr>');
      
      var $tdEmp = $('<td>');
      var $empFlex = $('<div>', { class: 'd-flex align-items-center gap-2' }).appendTo($tdEmp);
      $('<div>', { class: 'ft-avatar-sm', text: t.employee_initials }).appendTo($empFlex);
      var $empInfo = $('<div>').appendTo($empFlex);
      $('<div>', { class: 'fw-semibold small', text: t.employee_name }).appendTo($empInfo);
      if (t.employee_dept) {
        $('<div>', { class: 'text-muted ft-text-xs', text: t.employee_dept }).appendTo($empInfo);
      }
      $tdEmp.appendTo($tr);

      $('<td>', { class: 'small', text: t.categories }).appendTo($tr);
      var $tdToken = $('<td>');
      $('<span>', { class: 'badge bg-light border text-dark font-monospace', text: t.token_number }).appendTo($tdToken);
      $tdToken.appendTo($tr);
      $('<td>', { class: 'small text-muted', text: t.created_at }).appendTo($tr);
      
      $('<td>').append(tokenStatusBadge(t.status)).appendTo($tr);
      
      var $tdAction = $('<td>');
      $('<a>', { href: t.show_path, class: 'btn btn-sm btn-outline-secondary', text: 'View' }).appendTo($tdAction);
      $tdAction.appendTo($tr);

      $tbody.append($tr);
    });
  }

  // ── Utilities ─────────────────────────────────────────────────────
  function showDashboardLoading(show) {
    var $spinner = $('#dashboard-loading');
    if ($spinner.length) {
      show ? $spinner.removeClass('d-none') : $spinner.addClass('d-none');
    }
  }

  function toggleSection(selector, show) {
    var $el = $(selector);
    if ($el.length) show ? $el.removeClass('d-none') : $el.addClass('d-none');
  }

  function tokenStatusBadge(status) {
    if (status === 'redeemed') {
      return $('<span>', { class: 'badge bg-success', text: '✅ Redeemed' });
    } else if (status === 'expired') {
      return $('<span>', { class: 'badge bg-danger', text: '⏰ Expired' });
    } else if (status === 'active') {
      return $('<span>', { class: 'badge bg-warning text-dark', text: '⏳ Active' });
    } else {
      return $('<span>', { class: 'badge bg-secondary', text: status });
    }
  }

  function formatCurrency(amount) {
    return '₹' + parseFloat(amount || 0).toFixed(2);
  }

  // escHtml is no longer used since we use jQuery element creation (.text())


  // Init on every Turbo navigation and first load
  document.addEventListener('turbo:load',       init);
  document.addEventListener('DOMContentLoaded', init);

})();
