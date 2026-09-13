// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// The service worker keeps the offline form reachable without a network.
if ("serviceWorker" in navigator) {
  addEventListener("load", () => navigator.serviceWorker.register("/service-worker").catch(() => {}))
}
