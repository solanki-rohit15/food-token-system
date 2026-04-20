//= require jquery
//= require rails-ujs
//= require location
//= require app_ui
//= require scanner

// Flash auto-dismiss and clock (non-GPS UI)
document.addEventListener("DOMContentLoaded", function () {
  // Live clock
  var clockEl = document.getElementById("live-time");
  if (clockEl) {
    function updateClock() {
      var now  = new Date();
      var h    = now.getHours() % 12 || 12;
      var m    = now.getMinutes().toString().padStart(2, "0");
      var ampm = now.getHours() >= 12 ? "PM" : "AM";
      clockEl.textContent = h + ":" + m + " " + ampm;
    }
    updateClock();
    setInterval(updateClock, 30000);
  }
});
