import { Controller } from "@hotwired/stimulus"

// A side panel around the "modal" Turbo Frame. Any link with
// data-turbo-frame="modal" loads into it; the panel slides in when the
// frame has loaded and closes on × or Escape. It is non-modal on purpose:
// the map behind it stays usable. Closing empties the frame and tells the
// page (the map reloads its pins).
export default class extends Controller {
  connect() {
    this.onKey = (e) => { if (e.key === "Escape" && this.element.open) this.close() }
    document.addEventListener("keydown", this.onKey)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKey)
  }

  open() {
    if (!this.element.open) this.element.show()
    this.element.scrollTop = 0
  }

  close() {
    this.element.close()
  }

  closed() {
    const frame = this.element.querySelector("turbo-frame")
    frame.removeAttribute("src")
    frame.innerHTML = ""
    document.dispatchEvent(new CustomEvent("pano:modal-closed"))
  }
}
