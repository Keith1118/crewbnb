import { Controller } from "@hotwired/stimulus"

// Live price breakdown for the booking form: nights × nightly rate = total.
export default class extends Controller {
  static targets = ["checkIn", "checkOut", "nights", "subtotal", "total", "breakdown", "empty"]
  static values = { price: Number }

  connect() {
    this.recalculate()
  }

  recalculate() {
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
