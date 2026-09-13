import { Controller } from "@hotwired/stimulus"
import { syncClient } from "sync/client"

// The bar's "N waiting" badge: how many contributions this phone still
// has to send, hidden at zero. Tapping it sends now.
export default class extends Controller {
  static targets = ["count"]

  connect() {
    this.client = syncClient()
    this.unsubscribe = this.client.subscribe((entries) => this.render(entries))
  }

  disconnect() { this.unsubscribe?.() }

  render(entries) {
    const n = entries.filter((e) => !e.rejected).length
    const rejected = entries.length - n
    this.element.hidden = entries.length === 0
    this.countTarget.textContent = rejected ? `${n} waiting · ${rejected} refused` : `${n} waiting`
    this.element.classList.toggle("is-offline", !navigator.onLine)
  }

  send() { this.client.sync() }
}
