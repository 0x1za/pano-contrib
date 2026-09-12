import { Controller } from "@hotwired/stimulus"

// Keyboard for the review queue: j/k move, a accepts, r rejects, n focuses
// the note. Typing in the note never triggers a decision.
export default class extends Controller {
  static targets = ["item", "note", "accept", "reject"]

  connect() {
    this.index = 0
    this.focus()
    this.onKey = (e) => this.key(e)
    document.addEventListener("keydown", this.onKey)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKey)
  }

  key(e) {
    if (e.metaKey || e.ctrlKey || e.altKey) return
    const typing = e.target.matches("input, textarea")
    if (typing && e.key !== "Escape") return
    switch (e.key) {
      case "j": this.move(1); break
      case "k": this.move(-1); break
      case "a": this.acceptTargets[this.index]?.click(); break
      case "r": this.rejectTargets[this.index]?.click(); break
      case "n": e.preventDefault(); this.noteTargets[this.index]?.focus(); break
      case "Escape": this.focus(); break
      default: return
    }
    e.preventDefault()
  }

  move(by) {
    if (!this.itemTargets.length) return
    this.index = Math.min(Math.max(this.index + by, 0), this.itemTargets.length - 1)
    this.focus()
  }

  focus() {
    const item = this.itemTargets[this.index]
    if (!item) return
    this.itemTargets.forEach(el => el.classList.toggle("is-current", el === item))
    item.focus({ preventScroll: false })
  }
}
