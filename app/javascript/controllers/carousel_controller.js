import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["page", "counter"]

  connect() {
    this.index = 0
    this.updateCounter()
  }

  next() {
    if (this.index < this.pageTargets.length - 1) {
      this.pageTargets[this.index].classList.add("hidden")
      this.index++
      this.pageTargets[this.index].classList.remove("hidden")
      this.updateCounter()
    }
  }

  prev() {
    if (this.index > 0) {
      this.pageTargets[this.index].classList.add("hidden")
      this.index--
      this.pageTargets[this.index].classList.remove("hidden")
      this.updateCounter()
    }
  }

  updateCounter() {
    if (this.hasCounterTarget) {
      this.counterTarget.textContent = `${this.index + 1} / ${this.pageTargets.length}`
    }
  }
}
