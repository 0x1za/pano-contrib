// Deliberately minimal, after span: cache the offline form, the map page
// once someone saves the map, and digested assets; answer range requests
// for the saved tiles archive from its chunks; when a navigation fails
// offline, serve the saved map page or the offline form. Writes are the
// outbox's job, nothing clever lives here.
const CACHE = "pano-v2"
const TILES = "pano-tiles-v1"
const OFFLINE_URL = "/offline"
const TILES_PATH = "/tiles/pano.pmtiles"
const GLYPH_HOST = "fonts.openmaptiles.org"

self.addEventListener("install", (event) => {
  event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll([OFFLINE_URL])))
  self.skipWaiting()
})

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== CACHE && k !== TILES).map((k) => caches.delete(k)))).then(() => self.clients.claim())
  )
})

// A range of the saved archive, assembled from the chunks it spans.
async function savedRange(request) {
  const url = new URL(request.url)
  const base = url.origin + url.pathname
  const cache = await caches.open(TILES)
  const metaHit = await cache.match(`${base}?meta`)
  if (!metaHit) return null
  const meta = await metaHit.json()
  const m = /^bytes=(\d+)-(\d*)$/.exec(request.headers.get("Range") || "")
  const start = m ? Number(m[1]) : 0
  const end = m && m[2] ? Math.min(Number(m[2]), meta.size - 1) : meta.size - 1
  if (start > end) return new Response(null, { status: 416, headers: { "Content-Range": `bytes */${meta.size}` } })
  const first = Math.floor(start / meta.chunk), last = Math.floor(end / meta.chunk)
  const parts = []
  for (let i = first; i <= last; i++) {
    const hit = await cache.match(`${base}?chunk=${i}`)
    if (!hit) return null
    const bytes = new Uint8Array(await hit.arrayBuffer())
    const from = i === first ? start - i * meta.chunk : 0
    const to = i === last ? end - i * meta.chunk + 1 : bytes.length
    parts.push(bytes.subarray(from, to))
  }
  const body = new Blob(parts, { type: "application/octet-stream" })
  return new Response(body, {
    status: m ? 206 : 200,
    headers: {
      "Content-Type": "application/octet-stream",
      "Content-Length": String(end - start + 1),
      "Content-Range": `bytes ${start}-${end}/${meta.size}`,
      "Accept-Ranges": "bytes",
      "Access-Control-Allow-Origin": "*"
    }
  })
}

self.addEventListener("fetch", (event) => {
  const request = event.request
  if (request.method !== "GET") return
  const url = new URL(request.url)

  // The tiles archive, whichever origin serves it: the network first, so
  // a new gazetteer is never masked by an old saved copy; the saved copy
  // when the network fails.
  if (url.pathname.endsWith(TILES_PATH) && !url.search) {
    event.respondWith(fetch(request).catch(() => savedRange(request).then((hit) => hit || Response.error())))
    return
  }

  // Label glyphs: cache first, so labels survive without a network.
  if (url.hostname === GLYPH_HOST) {
    event.respondWith(
      caches.open(TILES).then((cache) => cache.match(request).then((hit) => hit || fetch(request).then((response) => {
        if (response.ok) cache.put(request, response.clone())
        return response
      })))
    )
    return
  }

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

  // Pages: network first so copy changes land; the saved map page or the
  // offline form when there is no network.
  if (request.mode === "navigate") {
    event.respondWith(
      fetch(request).then((response) => {
        if (url.pathname === OFFLINE_URL && response.ok) { const copy = response.clone(); caches.open(CACHE).then((cache) => cache.put(OFFLINE_URL, copy)) }
        return response
      }).catch(async () => (url.pathname === "/" && await caches.match("/")) || caches.match(OFFLINE_URL))
    )
  }
})
