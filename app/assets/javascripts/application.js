import "@hotwired/turbo-rails"
import "@rails/actioncable"

// Auto-dismiss toasts
document.addEventListener("turbo:load", () => {
  // Live clock update
  const clockEl = document.getElementById("live-time");
  if (clockEl) {
    setInterval(() => {
      const now = new Date();
      const h = now.getHours() % 12 || 12;
      const m = now.getMinutes().toString().padStart(2, "0");
      const ampm = now.getHours() >= 12 ? "PM" : "AM";
      clockEl.innerHTML = `<i class="bi bi-clock me-1"></i>${h}:${m} ${ampm}`;
    }, 30000);
  }

  // Auto dismiss toasts after 3s
  document.querySelectorAll(".toast").forEach(toast => {
    setTimeout(() => {
      toast.style.opacity = "0";
      toast.style.transition = "opacity 0.5s";
      setTimeout(() => toast.remove(), 500);
    }, 3000);
  });

  // Dashboard time display
  const dashTime = document.getElementById("dashboard-time");
  if (dashTime) {
    setInterval(() => {
      const now = new Date();
      const h = now.getHours() % 12 || 12;
      const m = now.getMinutes().toString().padStart(2, "0");
      const ampm = now.getHours() >= 12 ? "PM" : "AM";
      dashTime.textContent = `${h}:${m} ${ampm}`;
    }, 30000);
  }
});
