import { Controller } from "@hotwired/stimulus"
import { syncClient } from "sync/client"
import { savedMap, saveMap, removeMap, currentGazetteer, formatBytes } from "offline/map_store"

// The offline form: an address the person already knows plus what they
// want to say. Nothing is posted here; the entry goes to the outbox and
// the client sends it when the phone is back online. The list below the
// form is the outbox itself, including what the server refused and why.
export default class extends Controller {
  static targets = ["form", "address", "kind", "note", "sub", "reason", "list", "status", "noteField", "subField", "reasonField", "mapStatus", "mapProgress", "saveMap", "removeMap"]
  static values = { api: String }

  connect() {
    this.client = syncClient()
    this.unsubscribe = this.client.subscribe((entries) => this.render(entries))
    this.onLine = () => this.render(this.client.entries)
    addEventListener("online", this.onLine); addEventListener("offline", this.onLine)
    this.prefill()
    this.kindChanged()
    this.renderMap()
  }

  // The map's card sends people here with the address and what they tapped.
  prefill() {
    const params = new URLSearchParams(location.search)
    const address = params.get("address"), kind = params.get("kind")
    if (address) this.addressTarget.value = address.toUpperCase()
    if (kind && [...this.kindTarget.options].some((o) => o.value === kind)) this.kindTarget.value = kind
  }

  // ---------- the saved map ----------
  async renderMap() {
    if (!this.hasMapStatusTarget) return  // the saved map is behind the :offline_map flag
    const saved = await savedMap(this.apiValue)
    const now = saved ? await currentGazetteer(this.apiValue) : null
    const stale = saved && now && saved.hash && saved.hash !== now.hash
    this.mapStatusTarget.textContent = !saved
      ? "The map is not saved on this phone. Saved, the districts, units, buildings and numbers open without a network; the street map behind them and search still need one."
      : stale
        ? `Saved: ${formatBytes(saved.size)} of map v${saved.version}, ${new Date(saved.savedAt).toLocaleDateString()}. The map is now v${now.version}; save it again to take the new one with you.`
        : `Saved: ${formatBytes(saved.size)}${saved.version ? ` of map v${saved.version}` : ""}, ${new Date(saved.savedAt).toLocaleDateString()}. Districts, units, buildings and numbers open without a network.`
    this.mapStatusTarget.classList.toggle("is-offline", !!stale)
    this.saveMapTarget.textContent = saved ? (stale ? "Save the new map" : "Save it again") : "Save the map on this phone"
    this.removeMapTarget.hidden = !saved
  }

  async saveMap() {
    this.saveMapTarget.disabled = true
    this.mapProgressTarget.hidden = false
    this.mapProgressTarget.removeAttribute("value")
    try {
      await saveMap(this.apiValue, (done, total) => {
        if (total) { this.mapProgressTarget.max = total; this.mapProgressTarget.value = done }
        this.mapStatusTarget.textContent = `Saving… ${formatBytes(done)}${total ? ` of ${formatBytes(total)}` : ""}`
      })
    } catch (e) {
      this.mapStatusTarget.textContent = `Could not save the map: ${e.message}`
    } finally {
      this.mapProgressTarget.hidden = true
      this.saveMapTarget.disabled = false
    }
    await this.renderMap()
  }

  async removeMap() {
    await removeMap(this.apiValue)
    await this.renderMap()
  }

  disconnect() {
    this.unsubscribe?.()
    removeEventListener("online", this.onLine); removeEventListener("offline", this.onLine)
  }

  kindChanged() {
    const kind = this.kindTarget.value
    this.noteFieldTarget.hidden = kind !== "delivery_note"
    this.reasonFieldTarget.hidden = kind !== "dispute_address"
    this.subFieldTarget.hidden = kind !== "confirm_address"
  }

  async save(e) {
    e.preventDefault()
    const address = this.addressTarget.value.trim().toUpperCase()
    if (!/^[A-Z]{1,2}[1-9][0-9]? [1-9][A-Z]{2} [1-9][0-9]*(\/[A-Z0-9 ]{1,12})?$/.test(address)) {
      this.addressTarget.setCustomValidity("An address looks like LS33 9XX 17, or LS33 9XX 17/3 for a flat.")
      this.addressTarget.reportValidity()
      return
    }
    this.addressTarget.setCustomValidity("")
    const kind = this.kindTarget.value
    const args = { kind, address }
    if (kind === "delivery_note") args.note = this.noteTarget.value.trim()
    if (kind === "dispute_address") args.reason = this.reasonTarget.value
    if (kind === "confirm_address" && this.subTarget.value.trim()) args.sub = this.subTarget.value.trim()
    if (kind === "confirm_address" && address.includes("/")) args.sub = address.split("/")[1]
    await this.client.queue(args)
    this.formTarget.reset()
    this.kindChanged()
    this.addressTarget.focus()
  }

  forget(e) {
    this.client.forget(e.currentTarget.dataset.id)
  }

  render(entries) {
    const online = navigator.onLine
    this.statusTarget.textContent = online
      ? (entries.some((e) => !e.rejected) ? "Online. Sending…" : "Online. Everything on this phone has been sent.")
      : "Offline. What you save here is kept on this phone and sent when you are back online."
    this.statusTarget.classList.toggle("is-offline", !online)
    this.listTarget.replaceChildren(...entries.map((e) => {
      const li = document.createElement("li")
      li.className = "entry " + (e.rejected ? "is-rejected" : "is-pending")
      const a = e.mutation.args
      const label = { confirm_address: "I live here", delivery_note: "Delivery note", dispute_address: "Something is wrong" }[a.kind] || a.kind
      li.innerHTML = `<div class="entry-card"><span class="entry-main"><strong class="entry-label"></strong><span class="entry-kind"></span></span><span class="entry-side"><span class="pill"></span><button type="button" class="linklike">Remove</button></span></div>`
      li.querySelector(".entry-label").textContent = a.address
      li.querySelector(".entry-kind").textContent = [label, a.note, a.reason].filter(Boolean).join(" · ")
      const pill = li.querySelector(".pill")
      pill.textContent = e.rejected ? "Refused" : "Waiting"
      pill.classList.add(e.rejected ? "is-rejected" : "is-pending")
      if (e.rejected) pill.title = e.rejected
      const btn = li.querySelector("button"); btn.dataset.id = e.mutationId; btn.addEventListener("click", (ev) => this.forget(ev))
      if (e.rejected) { const why = document.createElement("p"); why.className = "hint"; why.textContent = e.rejected; li.append(why) }
      return li
    }))
  }
}
