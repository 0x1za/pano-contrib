import { Controller } from "@hotwired/stimulus"
import { syncClient } from "sync/client"

// The offline form: an address the person already knows plus what they
// want to say. Nothing is posted here; the entry goes to the outbox and
// the client sends it when the phone is back online. The list below the
// form is the outbox itself, including what the server refused and why.
export default class extends Controller {
  static targets = ["form", "address", "kind", "note", "sub", "reason", "list", "status", "noteField", "subField", "reasonField"]

  connect() {
    this.client = syncClient()
    this.unsubscribe = this.client.subscribe((entries) => this.render(entries))
    this.onLine = () => this.render(this.client.entries)
    addEventListener("online", this.onLine); addEventListener("offline", this.onLine)
    this.kindChanged()
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
