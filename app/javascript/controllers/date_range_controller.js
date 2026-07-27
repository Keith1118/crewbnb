import { Controller } from "@hotwired/stimulus"

// Keeps an end date after its start date. A date input's `min` is fixed at
// render time, so without this the browser happily accepts an end date months
// before the start — the booking form let exactly that through to the server.
//
// The booking form itself handles this inside booking_calc_controller, which
// already owns both fields; this is for the plainer date pairs (search, the
// host's block-out range).
export default class extends Controller {
  static targets = ["start", "end"]

  connect() {
    this.sync()
  }

  sync() {
    const start = this.startTarget.value
    if (!start) return

    const firstValid = this.nextDay(start)
    this.endTarget.min = firstValid

    // Pull an invalid end date up to the first valid one rather than clearing
    // it — losing the value entirely is more annoying than nudging it.
    if (this.endTarget.value && this.endTarget.value <= start) {
      this.endTarget.value = firstValid
    }
  }

  // ISO date strings compare correctly as strings, so this stays in "YYYY-MM-DD".
  nextDay(isoDate) {
    const date = new Date(`${isoDate}T00:00:00`)
    date.setDate(date.getDate() + 1)
    return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`
  }
}
