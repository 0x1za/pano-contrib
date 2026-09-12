import { Controller } from "@hotwired/stimulus"
import "maplibre-gl"
const maplibregl = window.maplibregl

// The map: the pano API draws the picture, this controller only asks it
// questions. A tap on a building or the ground calls /encode and fills the
// card; the card's buttons are plain links into the contribution forms.
export default class extends Controller {
  static targets = ["canvas", "card", "eyebrow", "address", "actions", "note", "welcome"]
  static values = {
    api: String,
    center: { type: Array, default: [28.32, -15.42] },
    zoom: { type: Number, default: 12 }
  }

  connect() {
    this.map = new maplibregl.Map({
      container: this.canvasTarget,
      style: {
        version: 8,
        glyphs: "https://fonts.openmaptiles.org/{fontstack}/{range}.pbf",
        sources: { osm: { type: "raster", tiles: ["https://tile.openstreetmap.org/{z}/{x}/{y}.png"], tileSize: 256, attribution: "© OpenStreetMap contributors" } },
        layers: [{ id: "osm", type: "raster", source: "osm", paint: { "raster-saturation": -1, "raster-opacity": 0.55 } }]
      },
      center: this.centerValue, zoom: this.zoomValue, minZoom: 9, maxZoom: 20
    })
    this.map.addControl(new maplibregl.NavigationControl({ showCompass: false }), "bottom-right")
    this.#maybeWelcome()
    this.map.on("load", () => this.#addLayers())
    this.map.on("moveend", () => this.#refresh())
    this.map.on("click", (e) => this.#click(e))
  }

  disconnect() { this.map?.remove() }

  async #addLayers() {
    const empty = { type: "FeatureCollection", features: [] }
    this.map.addSource("districts", { type: "geojson", data: empty })
    this.map.addSource("units", { type: "geojson", data: empty })
    this.map.addSource("buildings", { type: "geojson", data: empty })
    this.map.addSource("mine", { type: "geojson", data: empty })
    this.map.addSource("selected", { type: "geojson", data: empty })
    this.map.addLayer({ id: "districts-line", type: "line", source: "districts", paint: { "line-color": "#022EAC", "line-width": 1.5 } })
    this.map.addLayer({ id: "district-labels", type: "symbol", source: "districts", maxzoom: 13.5, layout: { "text-field": ["get", "name"], "text-font": ["Open Sans Bold"], "text-size": 13 }, paint: { "text-color": "#022EAC", "text-halo-color": "#fff", "text-halo-width": 1.6 } })
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
      districts.features.forEach(f => { f.geometry = { type: "Point", coordinates: [f.properties.centroid_lng, f.properties.centroid_lat] }; f.properties.name = `${f.properties.name || ""}\n${f.properties.code}` })
      this.map.getSource("districts").setData(districts)
    }
    const outlines = await this.#get("/districts")
    if (outlines) this.map.addLayer({ id: "districts-fill", type: "fill", source: { type: "geojson", data: outlines }, maxzoom: 13, paint: { "fill-color": "#022EAC", "fill-opacity": 0.05 } }, "districts-line")
    this.#refresh()
  }

  // The welcome card explains the site until dismissed once; the About
  // button in the bar brings it back.
  welcome() {
    this.cardTarget.hidden = true
    this.welcomeTarget.hidden = false
  }

  dismiss() {
    this.welcomeTarget.hidden = true
    try { localStorage.setItem("pano.welcomed", "1") } catch {}
  }

  #maybeWelcome() {
    let seen = false
    try { seen = localStorage.getItem("pano.welcomed") === "1" } catch {}
    if (!seen) this.welcomeTarget.hidden = false
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
    const mine = this.map.queryRenderedFeatures(e.point, { layers: ["mine-pins"] })
    if (mine.length) return this.#showMine(mine[0].properties)
    const hit = this.map.queryRenderedFeatures(e.point, { layers: ["buildings"] })
    const p = hit.length ? { lng: hit[0].geometry.coordinates[0], lat: hit[0].geometry.coordinates[1] } : e.lngLat
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
    this.#card("Address", b.address, [
      this.#link("This is my address", `/contributions/new?kind=confirm_address&building_id=${b.id}`, "btn"),
      this.#link("Something is wrong", `/contributions/new?kind=dispute_address&building_id=${b.id}`, "btn btn--ghost"),
      this.#link("Add a delivery note", `/contributions/new?kind=delivery_note&building_id=${b.id}`, "btn btn--ghost")
    ], `Unit ${body.code} · ${body.parents.district}`)
  }

  #showUnit(body) {
    this.#card("Unit", body.code, [
      this.#link("Name this place", `/contributions/new?kind=name_place&target_code=${encodeURIComponent(body.code)}`, "btn btn--ghost")
    ], "Tap a building for its address.")
  }

  #showDistrict(p) {
    const name = (p.name || "").split("\n")[0] || p.code
    this.#card("District", name, [
      this.#link(`Yes, this is ${name}`, `/contributions/new?kind=confirm_district&target_code=${encodeURIComponent(p.code)}`, "btn"),
      this.#link("No, it is called…", `/contributions/new?kind=dispute_district&target_code=${encodeURIComponent(p.code)}`, "btn btn--ghost")
    ], p.code)
  }

  #showMine(p) {
    const status = { pending: "Pending", accepted: "Accepted", rejected: "Rejected", superseded: "Superseded" }[p.status] || p.status
    const kind = p.kind.replaceAll("_", " ")
    this.#card(`Your contribution · ${status}`, p.label, [ this.#link("See it", p.url, "btn") ], p.name ? `${kind}: ${p.name}` : kind)
  }

  #showMessage(text) { this.#card("", "", [], text) }

  #card(eyebrow, headline, actions, note) {
    this.eyebrowTarget.textContent = eyebrow
    this.addressTarget.textContent = headline
    this.actionsTarget.replaceChildren(...actions)
    this.noteTarget.textContent = note
    this.welcomeTarget.hidden = true
    this.cardTarget.hidden = false
  }

  #link(text, href, cls) { const a = document.createElement("a"); a.href = href; a.className = cls; a.textContent = text; return a }

  async #get(path) {
    try { const r = await fetch(this.apiValue + path); return r.ok ? await r.json() : null } catch { return null }
  }
}
