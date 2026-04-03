import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "openIcon", "closeIcon"]

  toggle() {
    this.menuTarget.classList.toggle("hidden")

    if (this.hasOpenIconTarget && this.hasCloseIconTarget) {
      this.openIconTarget.classList.toggle("hidden")
      this.closeIconTarget.classList.toggle("hidden")
    }
  }

  close() {
    this.menuTarget.classList.add("hidden")

    if (this.hasOpenIconTarget && this.hasCloseIconTarget) {
      this.openIconTarget.classList.remove("hidden")
      this.closeIconTarget.classList.add("hidden")
    }
  }
}
