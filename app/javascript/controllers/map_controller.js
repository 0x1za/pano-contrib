import { Controller } from "@hotwired/stimulus"
import "maplibre-gl"
const maplibregl = window.maplibregl

// Plus code of a point at 10 characters, for the courier line. Same
// arithmetic as the pano page; the API's cell10 is preferred when it has one.
function plusCode(lat, lng) {
  const A = "23456789CFGHJMPQRVWX"
  let row = Math.floor((lat + 90) / 0.000125), col = Math.floor((lng + 180) / 0.000125)
  const d = []
  for (let i = 4; i >= 0; i--) { d.unshift(A[col % 20]); d.unshift(A[row % 20]); row = Math.floor(row / 20); col = Math.floor(col / 20) }
  return d.slice(0, 8).join("") + "+" + d.slice(8).join("")
}

// Point in a linear ring, by crossing count.
function inRing(ring, x, y) {
  let inside = false
  for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    const [xi, yi] = ring[i], [xj, yj] = ring[j]
    if ((yi > y) !== (yj > y) && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) inside = !inside
  }
  return inside
}

// The map: the pano API draws the picture, this controller only asks it
// questions. A tap on a building or the ground calls /encode and fills the
// card; the card's buttons are plain links into the contribution forms.
export default class extends Controller {
  static targets = ["canvas", "welcome", "query", "suggest"]
  static values = {
    api: String,
    satellite: String,
    center: { type: Array, default: [28.32, -15.42] },
    zoom: { type: Number, default: 12 }
  }

  connect() {
    this.map = new maplibregl.Map({
      container: this.canvasTarget,
      style: {
        version: 8,
        glyphs: "https://fonts.openmaptiles.org/{fontstack}/{range}.pbf",
        sources: {
          osm: { type: "raster", tiles: ["https://tile.openstreetmap.org/{z}/{x}/{y}.png"], tileSize: 256, attribution: "© OpenStreetMap contributors" },
          sat: { type: "raster", tiles: [this.satelliteValue], tileSize: 256, maxzoom: 19, attribution: "Imagery © Esri, Maxar, Earthstar Geographics, and the GIS User Community" }
        },
        layers: [
          { id: "sat", type: "raster", source: "sat", layout: { visibility: "none" } },
          { id: "osm", type: "raster", source: "osm", paint: { "raster-saturation": -1, "raster-opacity": 0.55 } }
        ]
      },
      center: this.centerValue, zoom: this.zoomValue, minZoom: 9, maxZoom: 20
    })
    this.map.addControl(new maplibregl.NavigationControl({ showCompass: false }), "bottom-right")
    this.map.addControl(this.#basemapControl(), "bottom-right")
    this.#maybeWelcome()
    this.onModalClosed = () => this.#loadMine()
    document.addEventListener("pano:modal-closed", this.onModalClosed)
    this.onDocClick = (e) => { if (!e.target.closest(".bar .search") && !e.target.closest(".suggest")) this.#closeSuggest() }
    document.addEventListener("click", this.onDocClick)
    this.map.on("load", () => this.#addLayers())
    this.map.on("moveend", () => this.#refresh())
    this.map.on("click", (e) => this.#click(e))
  }

  disconnect() {
    document.removeEventListener("pano:modal-closed", this.onModalClosed)
    document.removeEventListener("click", this.onDocClick)
    this.map?.remove()
  }

  async #addLayers() {
    const empty = { type: "FeatureCollection", features: [] }
    // Two views of the districts: outlines for the lines and fill, centroids for the labels.
    this.map.addSource("district-outlines", { type: "geojson", data: empty })
    this.map.addSource("districts", { type: "geojson", data: empty })
    this.map.addSource("units", { type: "geojson", data: empty })
    this.map.addSource("buildings", { type: "geojson", data: empty })
    this.map.addSource("mine", { type: "geojson", data: empty })
    this.map.addSource("selected", { type: "geojson", data: empty })
    // Halos sit under the lines and show only on imagery, where a bare line vanishes.
    this.map.addLayer({ id: "districts-fill", type: "fill", source: "district-outlines", maxzoom: 13, paint: { "fill-color": "#022EAC", "fill-opacity": 0.05 } })
    this.map.addLayer({ id: "districts-halo", type: "line", source: "district-outlines", layout: { visibility: "none" }, paint: { "line-color": "#0B0C11", "line-width": ["interpolate", ["linear"], ["zoom"], 10, 5, 14, 8], "line-opacity": 0.55, "line-blur": 1 } })
    this.map.addLayer({ id: "districts-line", type: "line", source: "district-outlines", paint: { "line-color": "#022EAC", "line-width": ["interpolate", ["linear"], ["zoom"], 10, 1.2, 14, 2.2], "line-opacity": 0.9 } })
    this.map.addLayer({ id: "district-labels", type: "symbol", source: "districts", maxzoom: 13.5, layout: { "text-field": ["get", "name"], "text-font": ["Open Sans Bold"], "text-size": 13 }, paint: { "text-color": "#022EAC", "text-halo-color": "#fff", "text-halo-width": 1.6 } })
    this.map.addLayer({ id: "units-halo", type: "line", source: "units", minzoom: 15, layout: { visibility: "none" }, paint: { "line-color": "#0B0C11", "line-width": 4.5, "line-opacity": 0.5, "line-blur": 1 } })
    this.map.addLayer({ id: "units-line", type: "line", source: "units", minzoom: 15, paint: { "line-color": "#022EAC", "line-width": 1, "line-opacity": 0.55 } })
    this.map.addLayer({ id: "selected-fill", type: "fill", source: "selected", paint: { "fill-color": "#FBA30C", "fill-opacity": 0.3 } })
    this.map.addLayer({ id: "selected-line", type: "line", source: "selected", paint: { "line-color": "#022EAC", "line-width": 3 } })
    this.map.addLayer({ id: "buildings", type: "circle", source: "buildings", minzoom: 15.5, paint: { "circle-radius": ["interpolate", ["linear"], ["zoom"], 15.5, 2, 17, 4.5, 19, 8], "circle-color": "#13E19B", "circle-stroke-color": "#022EAC", "circle-stroke-width": 0.7 } })
    this.map.addLayer({ id: "building-numbers", type: "symbol", source: "buildings", minzoom: 17, layout: { "text-field": ["to-string", ["get", "number"]], "text-font": ["Open Sans Bold"], "text-size": 11, "text-offset": [0, -1], "text-anchor": "bottom" }, paint: { "text-color": "#0B0C11", "text-halo-color": "#fff", "text-halo-width": 1.4 } })
    // The visitor's own contributions, coloured by what became of them.
    this.map.addLayer({ id: "mine-pins", type: "circle", source: "mine", paint: {
      "circle-radius": ["interpolate", ["linear"], ["zoom"], 10, 4, 15, 6, 19, 9],
      "circle-color": ["match", ["get", "status"], "accepted", "#0F7A32", "rejected", "#C8102E", "superseded", "#8A8F98", "#FBA30C"],
      "circle-stroke-color": "#fff", "circle-stroke-width": 2 } })
    this.map.on("mouseenter", "mine-pins", () => { this.map.getCanvas().style.cursor = "pointer" })
    this.map.on("mouseleave", "mine-pins", () => { this.map.getCanvas().style.cursor = "" })
    this.#loadMine()
    const districts = await this.#get("/districts")
    if (districts) {
      this.names = Object.fromEntries(districts.features.map(f => [f.properties.code, f.properties.name || ""]))
      this.map.getSource("district-outlines").setData(districts)
      const labels = { type: "FeatureCollection", features: districts.features.map(f => ({ type: "Feature", geometry: { type: "Point", coordinates: [f.properties.centroid_lng, f.properties.centroid_lat] }, properties: { ...f.properties, name: `${f.properties.name || ""}\n${f.properties.code}` } })) }
      this.map.getSource("districts").setData(labels)
    }
    this.#refresh()
    // The NSDI ward lines shaped the partition; the card names the ward a
    // point falls in when the server has the layer. Not part of the scheme.
    this.wards = await this.#get("/overlays/wards")
    try { this.satellite = localStorage.getItem("pano.basemap") === "sat" } catch { this.satellite = false }
    if (this.satellite) this.#applyBasemap()
  }

  // ---------- basemap: the muted street map, or aerial imagery to find your own roof ----------
  // The switch is the thumbnail in the corner everyone knows from Google
  // Maps: it shows the mode you would switch to, labelled, next to the zoom.
  #basemapControl() {
    const sat = this.satelliteValue.replace("{z}", "13").replace("{y}", "4451").replace("{x}", "4741")
    const osm = "https://tile.openstreetmap.org/13/4741/4451.png"
    const controller = this
    return {
      onAdd() {
        const div = document.createElement("div")
        div.className = "maplibregl-ctrl basemap-switch"
        const btn = document.createElement("button")
        btn.type = "button"; btn.className = "basemap-switch__btn"
        btn.setAttribute("aria-pressed", "false")
        btn.addEventListener("click", () => controller.toggleBasemap())
        div.append(btn)
        controller.basemapButton = btn
        controller.basemapThumbs = { sat, osm }
        controller.#paintBasemapButton()
        return div
      },
      onRemove() { controller.basemapButton = null }
    }
  }

  #paintBasemapButton() {
    const btn = this.basemapButton
    if (!btn) return
    const toSat = !this.satellite
    btn.style.backgroundImage = `url("${toSat ? this.basemapThumbs.sat : this.basemapThumbs.osm}")`
    btn.textContent = toSat ? "Satellite" : "Map"
    btn.title = toSat ? "Show aerial imagery" : "Show the street map"
    btn.setAttribute("aria-label", btn.title)
    btn.setAttribute("aria-pressed", String(this.satellite))
  }

  toggleBasemap() {
    this.satellite = !this.satellite
    try { localStorage.setItem("pano.basemap", this.satellite ? "sat" : "map") } catch {}
    this.#applyBasemap()
  }

  #applyBasemap() {
    const sat = this.satellite
    this.map.setLayoutProperty("sat", "visibility", sat ? "visible" : "none")
    this.map.setLayoutProperty("osm", "visibility", sat ? "none" : "visible")
    // Lines that read on a grey map vanish on imagery: switch them to white there.
    const line = sat ? "#FFFFFF" : "#022EAC"
    for (const id of ["districts-line", "units-line"]) if (this.map.getLayer(id)) this.map.setPaintProperty(id, "line-color", line)
    // Faint lines read on the grey map and vanish over roofs: heavier, with a dark halo, on imagery.
    if (this.map.getLayer("units-line")) {
      this.map.setPaintProperty("units-line", "line-opacity", sat ? 0.95 : 0.55)
      this.map.setPaintProperty("units-line", "line-width", sat ? 2 : 1)
    }
    if (this.map.getLayer("districts-line")) this.map.setPaintProperty("districts-line", "line-width", sat ? ["interpolate", ["linear"], ["zoom"], 10, 2.4, 14, 3.5] : ["interpolate", ["linear"], ["zoom"], 10, 1.2, 14, 2.2])
    for (const id of ["districts-halo", "units-halo"]) if (this.map.getLayer(id)) this.map.setLayoutProperty(id, "visibility", sat ? "visible" : "none")
    if (this.map.getLayer("district-labels")) this.map.setPaintProperty("district-labels", "text-color", sat ? "#FFFFFF" : "#022EAC")
    if (this.map.getLayer("district-labels")) this.map.setPaintProperty("district-labels", "text-halo-color", sat ? "rgba(0,0,0,.6)" : "#fff")
    this.#paintBasemapButton()
  }

  // ---------- search: the pano API's /search suggests, /resolve lands ----------
  suggest() {
    const q = this.queryTarget.value.trim()
    clearTimeout(this.suggestTimer)
    if (!q) return this.#closeSuggest()
    const seq = (this.suggestSeq = (this.suggestSeq || 0) + 1)
    this.suggestTimer = setTimeout(async () => {
      // Codes and districts from the pano API; streets and places people already know from the geocoder.
      const [codes, places] = await Promise.all([
        this.#get(`/search?q=${encodeURIComponent(q)}`),
        fetch(`/geocode?q=${encodeURIComponent(q)}`, { headers: { Accept: "application/json" } }).then(r => r.ok ? r.json() : []).catch(() => [])
      ])
      if (seq !== this.suggestSeq) return
      const list = [...(codes || []), ...places.map(p => ({ code: null, name: p.name, detail: p.detail, tier: p.kind, lat: p.lat, lng: p.lng }))].slice(0, 8)
      this.suggestions = list
      this.active = list.length ? 0 : -1
      this.#renderSuggest()
    }, 160)
  }

  searchKey(e) {
    if (!this.suggestions?.length) return
    if (e.key === "ArrowDown") { this.active = (this.active + 1) % this.suggestions.length; this.#renderSuggest(); e.preventDefault() }
    else if (e.key === "ArrowUp") { this.active = (this.active - 1 + this.suggestions.length) % this.suggestions.length; this.#renderSuggest(); e.preventDefault() }
    else if (e.key === "Escape") this.#closeSuggest()
  }

  pick(e) {
    const li = e.target.closest("li[data-i]")
    if (li) this.#choose(this.suggestions[Number(li.dataset.i)])
  }

  search(e) {
    e.preventDefault()
    if (this.suggestions?.length && this.active >= 0) return this.#choose(this.suggestions[this.active])
    const q = this.queryTarget.value.trim()
    if (q) this.#resolve(q)
  }

  #choose(x) {
    if (!x) return
    this.#closeSuggest()
    this.queryTarget.blur()
    if (!x.code) {
      // A street or place: fly there at building zoom and ask for the roof.
      this.queryTarget.value = x.name
      this.at = { lng: x.lng, lat: x.lat }
      this.map.easeTo({ center: [x.lng, x.lat], zoom: 17.5, duration: 700 })
      this.map.once("moveend", () => this.#card(x.tier === "street" ? "Street" : "Place", x.name, [], `${x.detail ? x.detail + " · " : ""}Tap your building to get its address.`))
      return
    }
    this.queryTarget.value = x.name && x.tier === "district" ? x.name : x.code
    this.#resolve(x.code, x.name)
  }

  async #resolve(text, name) {
    const res = await fetch(`${this.apiValue}/resolve/${encodeURIComponent(text)}`)
    const body = await res.json().catch(() => ({}))
    if (!res.ok) { this.at = this.map.getCenter(); return this.#showMessage(body.detail || `${text} is not in this gazetteer.`) }
    if (body.building) {
      const b = body.building
      this.at = { lng: b.lng, lat: b.lat }
      this.map.easeTo({ center: [b.lng, b.lat], zoom: 18, duration: 600 })
      this.map.once("moveend", () => this.#showBuilding({ building: b, code: body.units?.[0] || body.code.split(" ").slice(0, 2).join(" "), parents: body.parents }))
      return
    }
    this.map.getSource("selected").setData({ type: "Feature", geometry: body.boundary, properties: {} })
    this.#fitTo(body.boundary)
    this.at = { lng: body.centroid.lng, lat: body.centroid.lat }
    if (body.tier === "district") this.#showDistrict({ code: body.code, name: name || "" }, body)
    else if (body.tier === "sector") this.#showSector(body)
    else this.#showUnit(body)
  }

  #fitTo(geometry) {
    const b = [Infinity, Infinity, -Infinity, -Infinity]
    const visit = (c) => { if (typeof c[0] === "number") { b[0] = Math.min(b[0], c[0]); b[1] = Math.min(b[1], c[1]); b[2] = Math.max(b[2], c[0]); b[3] = Math.max(b[3], c[1]) } else c.forEach(visit) }
    visit(geometry.coordinates)
    if (isFinite(b[0])) this.map.fitBounds([[b[0], b[1]], [b[2], b[3]]], { padding: 60, duration: 600, maxZoom: 17 })
  }

  #renderSuggest() {
    const ul = this.suggestTarget
    if (!this.suggestions?.length) return this.#closeSuggest()
    ul.replaceChildren(...this.suggestions.map((x, i) => {
      const li = document.createElement("li"); li.role = "option"; li.dataset.i = i; li.className = i === this.active ? "is-active" : ""
      const left = document.createElement("span")
      const name = document.createElement("span"); name.className = "name"; name.textContent = x.name || x.code
      left.append(name)
      if (x.code && x.name) { const code = document.createElement("span"); code.className = "code"; code.textContent = x.code; left.append(code) }
      if (x.detail) { const d = document.createElement("span"); d.className = "detail"; d.textContent = x.detail; left.append(d) }
      const tier = document.createElement("span"); tier.className = "tier"; tier.textContent = x.tier
      li.append(left, tier); return li
    }))
    ul.classList.add("is-open")
    this.queryTarget.setAttribute("aria-expanded", "true")
  }

  #closeSuggest() {
    this.suggestions = []; this.active = -1
    this.suggestTarget.classList.remove("is-open")
    this.queryTarget.setAttribute("aria-expanded", "false")
  }

  // The welcome card explains the site until dismissed once; the About
  // button in the bar brings it back.
  welcome() {
    this.popup?.remove()
    if (!this.welcomeTarget.open) this.welcomeTarget.showModal()
  }

  welcomeBackdrop(e) {
    if (e.target === this.welcomeTarget) this.dismiss()
  }

  dismiss() {
    this.welcomeTarget.close()
    try { localStorage.setItem("pano.welcomed", "1") } catch {}
  }

  #maybeWelcome() {
    let seen = false
    try { seen = localStorage.getItem("pano.welcomed") === "1" } catch {}
    if (!seen) this.welcome()
  }

  async #refresh() {
    const b = this.map.getBounds()
    const bbox = [b.getWest(), b.getSouth(), b.getEast(), b.getNorth()].map(v => v.toFixed(5)).join(",")
    const z = this.map.getZoom()
    if (z >= 15) { const fc = await this.#get(`/units?bbox=${bbox}`); if (fc) this.map.getSource("units").setData(fc) }
    if (z >= 15.5) {
      const res = await this.#get(`/buildings?bbox=${bbox}`)
      if (res) this.map.getSource("buildings").setData({ type: "FeatureCollection", features: res.buildings.map(x => ({ type: "Feature", geometry: { type: "Point", coordinates: [x.lng, x.lat] }, properties: { id: x.id, code: x.code, number: x.number } })) })
    }
  }

  async #loadMine() {
    try {
      const r = await fetch("/contributions/pins", { headers: { Accept: "application/json" } })
      if (r.ok) this.map.getSource("mine").setData(await r.json())
    } catch {}
  }

  async #click(e) {
    this.at = e.lngLat
    const mine = this.map.queryRenderedFeatures(e.point, { layers: ["mine-pins"] })
    if (mine.length) { this.at = { lng: mine[0].geometry.coordinates[0], lat: mine[0].geometry.coordinates[1] }; return this.#showMine(mine[0].properties) }
    const hit = this.map.queryRenderedFeatures(e.point, { layers: ["buildings"] })
    const p = hit.length ? { lng: hit[0].geometry.coordinates[0], lat: hit[0].geometry.coordinates[1] } : e.lngLat
    this.at = p
    if (this.map.getZoom() < 13 && !hit.length) {
      const d = this.map.queryRenderedFeatures(e.point, { layers: ["districts-fill"] })
      if (d.length) return this.#showDistrict(d[0].properties)
    }
    const res = await fetch(`${this.apiValue}/encode?lat=${p.lat}&lng=${p.lng}`)
    const body = await res.json()
    if (!res.ok) return this.#showMessage(body.nearest ? `No address here. Nearest unit is ${body.nearest.code}, ${Math.round(body.nearest.distance_m)} m away.` : "No address here.")
    this.map.getSource("selected").setData({ type: "Feature", geometry: body.boundary, properties: {} })
    if (body.building) this.#showBuilding(body) ; else this.#showUnit(body)
  }

  #showBuilding(body) {
    const b = body.building
    const unit = body.code
    const district = body.parents.district
    const name = this.names?.[district] || ""
    const facts = []
    if (b.subs?.length) facts.push(["Homes", b.subs.join(", ")])
    facts.push(["Plus code", plusCode(b.lat, b.lng)])
    const ward = this.#wardAt(b.lng, b.lat); if (ward) facts.push(["Ward", ward])
    facts.push(["Coordinates", `${b.lat.toFixed(5)}, ${b.lng.toFixed(5)}`])
    this.#card({
      eyebrow: "Address", headline: b.address, sub: name ? `${name} · ${district}` : district,
      crumbs: this.#crumbs(district, body.parents.sector, unit, b.number),
      actions: [
        this.#link("I live here", `/contributions/new?kind=confirm_address&building_id=${b.id}`, "btn"),
        this.#link("Several homes in this building", `/contributions/new?kind=multi_occupancy&building_id=${b.id}`, "btn"),
        this.#link("Something is wrong", `/contributions/new?kind=dispute_address&building_id=${b.id}`, "btn btn--ghost"),
        this.#link("Add a delivery note", `/contributions/new?kind=delivery_note&building_id=${b.id}`, "btn btn--ghost")
      ],
      tools: [ this.#copy("Copy address", b.address), this.#directions(b.lat, b.lng) ],
      facts, note: "Say the unit code, then the number. Couriers can use the plus code or the directions."
    })
  }

  // From a tap, /encode has no structure count; /resolve does.
  async #showUnit(body) {
    const full = body.structures === undefined ? await this.#get(`/resolve/${encodeURIComponent(body.code)}`) : null
    const structures = body.structures ?? full?.structures
    const district = body.parents.district
    const name = this.names?.[district] || ""
    const facts = []
    if (structures !== undefined) facts.push(["Buildings", String(structures)])
    if (body.cell10) facts.push(["Plus code", body.cell10])
    const ward = this.#wardAt(this.at.lng, this.at.lat); if (ward) facts.push(["Ward", ward])
    facts.push(["Coordinates", `${this.at.lat.toFixed(5)}, ${this.at.lng.toFixed(5)}`])
    this.#card({
      eyebrow: "Unit · about forty buildings", headline: body.code, sub: name ? `${name} · ${district}` : district,
      crumbs: this.#crumbs(district, body.parents.sector, body.code),
      tools: [ this.#copy("Copy code", body.code), this.#directions(this.at.lat, this.at.lng) ],
      facts, note: "Tap a building for its address."
    })
  }

  #showSector(body) {
    const district = body.parents.district
    const name = this.names?.[district] || ""
    this.#card({
      eyebrow: "Sector", headline: body.code, sub: name ? `${name} · ${district}` : district,
      crumbs: this.#crumbs(district, body.code),
      tools: [ this.#copy("Copy code", body.code) ],
      facts: [ ["Buildings", String(body.structures)], ["Units", String(body.units?.length || 0)] ],
      note: "Tap inside to go down a level."
    })
  }

  // From a tap at city zoom only the outline's properties are known; the
  // counts come from /resolve.
  async #showDistrict(p, body) {
    const name = (p.name || "").split("\n")[0] || this.names?.[p.code] || p.code
    const full = body || await this.#get(`/resolve/${encodeURIComponent(p.code)}`)
    const facts = []
    if (full?.structures !== undefined) facts.push(["Buildings", String(full.structures)])
    if (full?.units) {
      facts.push(["Sectors", String(new Set(full.units.map(u => u.split(" ")[1][0])).size)])
      facts.push(["Units", String(full.units.length)])
    }
    this.#card({
      eyebrow: "District", headline: name, sub: p.code,
      crumbs: this.#crumbs(p.code),
      actions: [ this.#link(`Yes, this is ${name}`, `/contributions/new?kind=confirm_district&target_code=${encodeURIComponent(p.code)}`, "btn") ],
      facts, note: "Zoom in to tap a building."
    })
  }

  #showMine(p) {
    const status = { pending: "Pending", accepted: "Accepted", rejected: "Rejected", superseded: "Superseded" }[p.status] || p.status
    const kind = p.kind.replaceAll("_", " ")
    this.#card({ eyebrow: `Your contribution · ${status}`, headline: p.label, actions: [ this.#link("See it", p.url, "btn") ], note: p.name ? `${kind}: ${p.name}` : kind })
  }

  // District › Sector › Unit › No., each a step back up the hierarchy.
  #crumbs(district, sector, unit, number) {
    const crumb = (code, label, current) => {
      const a = document.createElement("a")
      a.textContent = label; a.className = current ? "is-current" : ""
      if (!current) { a.href = "#"; a.addEventListener("click", (e) => { e.preventDefault(); this.#resolve(code, code === district ? this.names?.[district] : undefined) }) }
      return a
    }
    const current = number !== undefined ? "number" : unit ? "unit" : sector ? "sector" : "district"
    const parts = [ crumb(district, this.names?.[district] || district, current === "district") ]
    if (sector) parts.push(crumb(sector, `Sector ${sector.split(" ")[1]}`, current === "sector"))
    if (unit) parts.push(crumb(unit, `Unit ${unit.split(" ")[1]}`, current === "unit"))
    if (number !== undefined) parts.push(crumb(null, `No. ${number}`, true))
    return parts
  }

  // Which NSDI ward a point falls in, by ray casting over the overlay.
  #wardAt(lng, lat) {
    for (const f of this.wards?.features || []) {
      const polys = f.geometry.type === "Polygon" ? [f.geometry.coordinates] : f.geometry.coordinates
      for (const rings of polys) {
        if (inRing(rings[0], lng, lat) && !rings.slice(1).some(h => inRing(h, lng, lat))) return f.properties.name || f.properties.constituency || null
      }
    }
    return null
  }

  #copy(label, text) {
    const b = document.createElement("button")
    b.type = "button"; b.className = "btn btn--ghost btn--small"; b.textContent = label
    b.addEventListener("click", async () => {
      try { await navigator.clipboard.writeText(text); b.textContent = "Copied" } catch { b.textContent = text }
      setTimeout(() => { b.textContent = label }, 1500)
    })
    return b
  }

  #directions(lat, lng) {
    const a = document.createElement("a")
    a.className = "btn btn--ghost btn--small"; a.textContent = "Directions ↗"
    a.href = `https://www.google.com/maps/dir/?api=1&destination=${lat.toFixed(6)},${lng.toFixed(6)}`; a.target = "_blank"; a.rel = "noopener"
    return a
  }

  #showMessage(text) { this.#card({ note: text }) }

  // A popup anchored where the person tapped, in place of a bottom sheet:
  // what the place is, where it sits in the hierarchy, what you can say
  // about it, and the facts a courier wants.
  #card({ eyebrow, headline, sub, crumbs = [], actions = [], tools = [], facts = [], note }) {
    const el = document.createElement("div")
    const add = (tag, cls, text) => { const n = document.createElement(tag); n.className = cls; n.textContent = text; el.append(n); return n }
    if (eyebrow) add("p", "eyebrow", eyebrow)
    if (headline) {
      const h = add("p", "address", headline)
      if (sub) { const sm = document.createElement("small"); sm.textContent = sub; h.append(sm) }
    }
    if (crumbs.length) {
      const c = add("div", "crumbs", "")
      crumbs.forEach((a, i) => { if (i) { const sep = document.createElement("span"); sep.className = "sep"; sep.textContent = "›"; c.append(sep) } c.append(a) })
    }
    if (actions.length) { const a = add("div", "actions", ""); a.replaceChildren(...actions) }
    if (tools.length) { const t = add("div", "actions actions--row", ""); t.replaceChildren(...tools) }
    if (facts.length) {
      const dl = add("dl", "facts", "")
      for (const [k, v] of facts) { const d = document.createElement("div"); const dt = document.createElement("dt"); dt.textContent = k; const dd = document.createElement("dd"); dd.textContent = v; d.append(dt, dd); dl.append(d) }
    }
    if (note) add("p", "note", note)
    this.popup?.remove()
    this.popup = new maplibregl.Popup({ closeButton: true, closeOnClick: true, maxWidth: "42rem", offset: 10, focusAfterOpen: false })
      .setLngLat(this.at).setDOMContent(el).addTo(this.map)
    // On a phone the card takes the width; the corner controls step aside.
    this.canvasTarget.classList.add("has-card")
    this.popup.on("close", () => this.canvasTarget.classList.remove("has-card"))
    this.#fitPopup()
  }

  // A card with facts is taller than the tap point allows for; pan the
  // map so the whole card is on screen, under the bar.
  #fitPopup() {
    const el = this.popup?.getElement(); if (!el) return
    const rect = el.getBoundingClientRect(), box = this.canvasTarget.getBoundingClientRect()
    const bar = this.element.querySelector(".bar")?.getBoundingClientRect().bottom ?? box.top
    let dy = 0
    if (rect.bottom > box.bottom - 12) dy = rect.bottom - (box.bottom - 12)
    if (rect.top - dy < bar + 12) dy = rect.top - (bar + 12)
    if (dy) this.map.panBy([0, dy], { duration: 250 })
  }

  // Contribution forms open in the page's modal frame over the map.
  #link(text, href, cls) {
    const a = document.createElement("a")
    a.href = href; a.className = cls; a.textContent = text
    if (href.startsWith("/contributions/")) a.dataset.turboFrame = "modal"
    return a
  }

  async #get(path) {
    try { const r = await fetch(this.apiValue + path); return r.ok ? await r.json() : null } catch { return null }
  }
}
