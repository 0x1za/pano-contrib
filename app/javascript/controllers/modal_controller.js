import { Controller } from "@hotwired/stimulus"

// A native <dialog> around the "modal" Turbo Frame. Any link with
// data-turbo-frame="modal" loads into it; the dialog opens when the frame
// has loaded and closes on ×, Escape or a click on the backdrop. Closing
// empties the frame and tells the page (the map reloads its pins).
export default class extends Controller {
  open() {
    if (!this.element.open) this.element.showModal()
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

  backdrop(e) {
    if (e.target === this.element) this.close()
  }
}
