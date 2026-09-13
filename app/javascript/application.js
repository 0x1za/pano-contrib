// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// The service worker keeps the offline form and the saved map reachable
// without a network, behind the :offline_map flag. Off, any worker a phone
// still carries is unregistered and its caches cleared, so nothing stale
// can answer for the live site.
if ("serviceWorker" in navigator) {
  const on = document.documentElement.dataset.offline === "1"
  addEventListener("load", async () => {
    try {
      if (on) { await navigator.serviceWorker.register("/service-worker"); return }
      for (const r of await navigator.serviceWorker.getRegistrations()) await r.unregister()
      for (const k of await caches.keys()) await caches.delete(k)
    } catch {}
  })
}
