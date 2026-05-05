//= require jquery
//= require rails-ujs
//= require api
//= require ui
//= require location
//= require app_ui
//= require dashboard
//= require scanner
//= require bootstrap

// Live clock — employee hero section
document.addEventListener('DOMContentLoaded', function () {
  var clockEl = document.getElementById('live-time');
  if (clockEl) {
    function updateClock() {
      var d = new Date();
      var h = d.getHours() % 12 || 12;
      var m = d.getMinutes().toString().padStart(2, '0');
      clockEl.textContent = h + ':' + m + ' ' + (d.getHours() >= 12 ? 'PM' : 'AM');
    }
    updateClock();
    setInterval(updateClock, 30000);
  }
});

// Admin food item toggle
function toggleItem(id) {
  FT.apiRequest({
    url:    '/admin/food_items/' + id + '/toggle_active',
    method: 'PATCH'
  })
  .then(function (data) {
    var el = document.getElementById('food_item_' + data.id);
    if (el) el.classList.toggle('inactive', !data.active);
  })
  .catch(FT.handleError);
}
window.toggleItem = toggleItem;
