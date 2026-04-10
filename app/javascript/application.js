// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Auto-dismiss flash messages after 5 seconds
document.addEventListener("DOMContentLoaded", function () {
  const flashes = document.querySelectorAll(".ft-flash");
  flashes.forEach(function (el) {
    setTimeout(function () {
      el.style.transition = "opacity 0.5s";
      el.style.opacity = "0";
      setTimeout(function () { el.remove(); }, 500);
    }, 5000);
  });
});
