// The saved map: the pano tiles archive, the map page and what it needs,
// kept in the Cache API so the map opens with no network. The archive is
// stored in fixed chunks under its own URL plus a query string; the
// service worker answers range requests for it from those chunks, so
// MapLibre reads the saved copy exactly as it reads the live one.

export const TILES_CACHE = "pano-tiles-v1"
export const PAGE_CACHE = "pano-v2"
export const CHUNK = 1024 * 1024
export const TILES_PATH = "/tiles/pano.pmtiles"
export const GLYPHS = ["https://fonts.openmaptiles.org/Open%20Sans%20Bold/0-255.pbf"]

export function metaKey(url) { return `${url}?meta` }
export function chunkKey(url, i) { return `${url}?chunk=${i}` }

// What is saved, or null.
export async function savedMap(apiUrl) {
  try {
    const cache = await caches.open(TILES_CACHE)
    const hit = await cache.match(metaKey(apiUrl + TILES_PATH))
    return hit ? await hit.json() : null
  } catch { return null }
}

// Downloads the archive in one streamed request and stores it chunk by
// chunk, reporting bytes so far; then warms the page, its assets and the
// label font so the whole map opens offline.
export async function saveMap(apiUrl, onProgress = () => {}) {
  const url = apiUrl + TILES_PATH
  const cache = await caches.open(TILES_CACHE)
  const res = await fetch(url)
  if (!res.ok) throw new Error(`the tiles archive is not available (${res.status})`)
  const size = Number(res.headers.get("content-length")) || 0
  const reader = res.body.getReader()
  let buffer = new Uint8Array(0), index = 0, done = 0
  const flush = async (bytes) => {
    await cache.put(chunkKey(url, index), new Response(bytes, { headers: { "Content-Type": "application/octet-stream" } }))
    index += 1
  }
  for (;;) {
    const { value, done: end } = await reader.read()
    if (end) break
    const joined = new Uint8Array(buffer.length + value.length)
    joined.set(buffer); joined.set(value, buffer.length)
    buffer = joined
    done += value.length
    while (buffer.length >= CHUNK) { await flush(buffer.slice(0, CHUNK)); buffer = buffer.slice(CHUNK) }
    onProgress(done, size)
  }
  if (buffer.length) await flush(buffer)
  const gazetteer = await currentGazetteer(apiUrl)
  const meta = { size: done, chunk: CHUNK, chunks: index, savedAt: new Date().toISOString(), version: gazetteer?.version || null, hash: gazetteer?.hash || null }
  await cache.put(metaKey(url), new Response(JSON.stringify(meta), { headers: { "Content-Type": "application/json" } }))
  await warmPage()
  return meta
}

// Which gazetteer the API serves right now, or null without a network.
export async function currentGazetteer(apiUrl) {
  try {
    const r = await fetch(apiUrl + "/meta")
    if (!r.ok) return null
    const m = await r.json()
    return { version: m.version, hash: m.hash }
  } catch { return null }
}

export async function removeMap(apiUrl) {
  const url = apiUrl + TILES_PATH
  const cache = await caches.open(TILES_CACHE)
  const keys = await cache.keys()
  await Promise.all(keys.filter((r) => r.url.startsWith(url)).map((r) => cache.delete(r)))
}

// The map page, every asset it names, and the glyph range the labels use.
async function warmPage() {
  const page = await caches.open(PAGE_CACHE)
  const res = await fetch("/", { credentials: "same-origin" })
  if (!res.ok) return
  const html = await res.clone().text()
  await page.put("/", res)
  const urls = new Set()
  for (const m of html.matchAll(/(?:src|href)="(\/assets\/[^"]+)"/g)) urls.add(m[1])
  const importmap = html.match(/<script type="importmap"[^>]*>([\s\S]*?)<\/script>/)
  if (importmap) {
    try { for (const v of Object.values(JSON.parse(importmap[1]).imports || {})) if (v.startsWith("/assets/")) urls.add(v) } catch {}
  }
  await Promise.all([...urls].map(async (u) => { try { const r = await fetch(u); if (r.ok) await page.put(u, r) } catch {} }))
  const tiles = await caches.open(TILES_CACHE)
  await Promise.all(GLYPHS.map(async (u) => { try { const r = await fetch(u); if (r.ok) await tiles.put(u, r) } catch {} }))
}

export function formatBytes(n) {
  return n >= 1e6 ? `${(n / 1e6).toFixed(n >= 1e7 ? 0 : 1)} MB` : `${Math.round(n / 1e3)} KB`
}
