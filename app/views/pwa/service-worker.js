// Deliberately minimal, after span: cache the offline form and digested
// assets; when a navigation fails offline, serve the offline form. Writes
// are the outbox's job, nothing clever lives here.
const CACHE = "pano-v1"
const OFFLINE_URL = "/offline"

self.addEventListener("install", (event) => {
  event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll([OFFLINE_URL])))
  self.skipWaiting()
})

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)))).then(() => self.clients.claim())
  )
})

self.addEventListener("fetch", (event) => {
  const request = event.request
  if (request.method !== "GET") return
  const url = new URL(request.url)
  if (url.origin !== location.origin) return

  // Digested assets and the vendored JS are immutable: cache first.
  if (url.pathname.startsWith("/assets/")) {
    event.respondWith(
      caches.match(request).then((hit) => hit || fetch(request).then((response) => {
        if (response.ok) { const copy = response.clone(); caches.open(CACHE).then((cache) => cache.put(request, copy)) }
        return response
      }))
    )
    return
  }

  // The offline form itself: network first so copy changes land, cached copy when there is no network.
  if (request.mode === "navigate") {
    event.respondWith(
      fetch(request).then((response) => {
        if (url.pathname === OFFLINE_URL && response.ok) { const copy = response.clone(); caches.open(CACHE).then((cache) => cache.put(OFFLINE_URL, copy)) }
        return response
      }).catch(() => caches.match(OFFLINE_URL))
    )
  }
})
