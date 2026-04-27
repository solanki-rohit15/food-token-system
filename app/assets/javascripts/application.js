//= require jquery
//= require rails-ujs
//= require location
//= require app_ui
//= require scanner
//= require bootstrap

// Live clock displayed in employee hero section — updates every 30s
document.addEventListener("DOMContentLoaded", function () {
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

// Admin food item toggle — called from food_items/index view
function toggleItem(id) {
  fetch("/admin/food_items/" + id + "/toggle_active", {
    method: "PATCH",
    headers: {
      "X-CSRF-Token": document.querySelector("[name=csrf-token]").content,
      "Content-Type": "application/json"
    }
  })
  .then(function (res) { return res.json() })
  .then(function (data) {
    var el = document.getElementById("food_item_" + data.id)
    if (el) el.classList.toggle("inactive", !data.active)
  })
}

window.toggleItem = toggleItem
