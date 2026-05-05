/**
 * ui.js — Shared UI utilities
 *
 * Provides:
 *   FT.showFlash(type, message)   — toast notification
 *   FT.showSpinner(btn)           — button loading state
 *   FT.resetButton(btn, label)    — restore button after loading
 *   FT.handleError(err)           — standard error handler
 */
(function (global) {
  'use strict';

  /**
   * showFlash(type, message)
   * type: 'success' | 'error' | 'warning'
   */
  function showFlash(type, message) {
    if (!message) return;

    // Remove any existing flash
    var existing = document.querySelector('.ft-flash');
    if (existing) existing.remove();

    var typeMap = {
      success: { cls: 'ft-flash-success', icon: 'bi-check-circle-fill' },
      error:   { cls: 'ft-flash-danger',  icon: 'bi-exclamation-triangle-fill' },
      warning: { cls: 'ft-flash-warning', icon: 'bi-exclamation-circle-fill' }
    };
    var config = typeMap[type] || typeMap.error;

    var $flash = $('<div>', { class: 'ft-flash ' + config.cls });
    $('<i>', { class: 'bi ' + config.icon + ' me-2' }).appendTo($flash);
    $flash.append(document.createTextNode(message));
    $('<button>', {
      type: 'button',
      class: 'ft-flash-close js-flash-close',
      'aria-label': 'Dismiss',
      text: '×'
    }).appendTo($flash);

    $('body').prepend($flash);
    setTimeout(function () { $flash.fadeOut(400, function () { $(this).remove(); }); }, 5000);
  }

  /**
   * showSpinner(btn, text?)
   * Disables a button and shows a spinner.
   * Stores original HTML on the element for restoration.
   */
  function showSpinner(btn, text) {
    var $btn = $(btn);
    $btn.data('original-html', $btn.html());
    var spinner = $('<span>', { class: 'spinner-border spinner-border-sm me-2', 'aria-hidden': 'true' });
    $btn.prop('disabled', true).empty().append(spinner).append(document.createTextNode(text || 'Loading…'));
  }

  /**
   * resetButton(btn, label?)
   * Restores button to original HTML or a provided label.
   */
  function resetButton(btn, label) {
    var $btn = $(btn);
    if (label) {
      $btn.prop('disabled', false).html(label);
    } else {
      var original = $btn.data('original-html');
      $btn.prop('disabled', false).html(original || 'Submit');
    }
  }

  /**
   * handleError(err)
   * Standard handler for apiRequest() rejections.
   * Shows a flash message with the error text.
   */
  function handleError(err) {
    var msg = (err && err.message) ? err.message : 'An unexpected error occurred. Please try again.';
    showFlash('error', msg);
  }

  global.FT = global.FT || {};
  global.FT.showFlash   = showFlash;
  global.FT.showSpinner = showSpinner;
  global.FT.resetButton = resetButton;
  global.FT.handleError = handleError;

})(window);
