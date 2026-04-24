//= require jquery
//= require rails-ujs
//= require location
//= require app_ui
//= require scanner
//= require bootstrap 

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

function toggleItem(id) {
  fetch(`/admin/food_items/${id}/toggle_active`, {
    method: "PATCH",
    headers: {
      "X-CSRF-Token": document.querySelector("[name=csrf-token]").content,
      "Content-Type": "application/json"
    }
  })
  .then(res => res.json())
  .then(data => {
    const el = document.getElementById(`food_item_${data.id}`)
    el.classList.toggle("inactive", !data.active)
  })
}

// global banana zaroori hai (important)
window.toggleItem = toggleItem
