import { Controller } from "@hotwired/stimulus"

// Live price breakdown for the booking form: nights × nightly rate = total.
export default class extends Controller {
  static targets = ["checkIn", "checkOut", "nights", "subtotal", "total", "breakdown", "empty"]
  static values = { price: Number }

  connect() {
    this.recalculate()
  }

  recalculate() {
    this.enforceCheckOutAfterCheckIn()

    const checkIn = this.parseDate(this.checkInTarget.value)
    const checkOut = this.parseDate(this.checkOutTarget.value)

    if (!checkIn || !checkOut || checkOut <= checkIn) {
      this.showEmpty()
      return
    }

    const nights = Math.round((checkOut - checkIn) / 86400000)
    const total = nights * this.priceValue

    if (this.hasNightsTarget) this.nightsTarget.textContent = nights
    if (this.hasSubtotalTarget) this.subtotalTarget.textContent = this.format(total)
    if (this.hasTotalTarget) this.totalTarget.textContent = this.format(total)

    if (this.hasBreakdownTarget) this.breakdownTarget.classList.remove("hidden")
    if (this.hasEmptyTarget) this.emptyTarget.classList.add("hidden")
  }

  // A date input only knows the static `min` it was rendered with, so nothing
  // stopped a check-out months BEFORE check-in — the form submitted and the
  // model rejected it. Move the floor as check-in changes, and pull an already
  // invalid check-out up to the first valid night rather than silently
  // clearing it.
  enforceCheckOutAfterCheckIn() {
    const checkIn = this.checkInTarget.value
    if (!checkIn) return

    const firstNight = this.nextDay(checkIn)
    this.checkOutTarget.min = firstNight

    if (this.checkOutTarget.value && this.checkOutTarget.value <= checkIn) {
      this.checkOutTarget.value = firstNight
    }
  }

  // ISO date strings compare correctly as strings, so this stays in "YYYY-MM-DD".
  nextDay(isoDate) {
    const date = new Date(`${isoDate}T00:00:00`)
    date.setDate(date.getDate() + 1)
    return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`
  }

  showEmpty() {
    if (this.hasNightsTarget) this.nightsTarget.textContent = "--"
    if (this.hasSubtotalTarget) this.subtotalTarget.textContent = "--"
    if (this.hasTotalTarget) this.totalTarget.textContent = "--"

    if (this.hasEmptyTarget) {
      this.emptyTarget.classList.remove("hidden")
      if (this.hasBreakdownTarget) this.breakdownTarget.classList.add("hidden")
    }
  }

  parseDate(value) {
    if (!value) return null
    const date = new Date(`${value}T00:00:00`)
    return isNaN(date) ? null : date
  }

  format(amount) {
    return new Intl.NumberFormat("en-IE", { style: "currency", currency: "EUR", maximumFractionDigits: 0 }).format(amount)
  }
}
