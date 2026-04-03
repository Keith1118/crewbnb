import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["cardNumber", "expiry", "cvv", "cardIcon", "submitButton", "submitText", "submitSpinner"]

  formatCardNumber(event) {
    let value = event.target.value.replace(/\D/g, "")
    if (value.length > 16) value = value.substring(0, 16)
    // Add spaces every 4 digits
    value = value.replace(/(\d{4})(?=\d)/g, "$1 ")
    event.target.value = value

    this.updateCardIcon(value.replace(/\s/g, ""))
  }

  formatExpiry(event) {
    let value = event.target.value.replace(/\D/g, "")
    if (value.length > 4) value = value.substring(0, 4)
    if (value.length >= 2) {
      value = value.substring(0, 2) + " / " + value.substring(2)
    }
    event.target.value = value
  }

  formatCvv(event) {
    let value = event.target.value.replace(/\D/g, "")
    if (value.length > 4) value = value.substring(0, 4)
    event.target.value = value
  }

  updateCardIcon(number) {
    if (!this.hasCardIconTarget) return

    if (number.startsWith("4")) {
      this.cardIconTarget.textContent = "Visa"
      this.cardIconTarget.className = "text-xs font-bold text-blue-600 bg-blue-50 px-2 py-0.5 rounded"
    } else if (number.startsWith("5") || number.startsWith("2")) {
      this.cardIconTarget.textContent = "Mastercard"
      this.cardIconTarget.className = "text-xs font-bold text-orange-600 bg-orange-50 px-2 py-0.5 rounded"
    } else if (number.startsWith("3")) {
      this.cardIconTarget.textContent = "Amex"
      this.cardIconTarget.className = "text-xs font-bold text-indigo-600 bg-indigo-50 px-2 py-0.5 rounded"
    } else {
      this.cardIconTarget.textContent = ""
      this.cardIconTarget.className = ""
    }
  }

  submit(event) {
    event.preventDefault()

    // Show processing state
    this.submitButtonTarget.disabled = true
    this.submitTextTarget.classList.add("hidden")
    this.submitSpinnerTarget.classList.remove("hidden")

    // Simulate processing delay for realism
    setTimeout(() => {
      event.target.closest("form").submit()
    }, 1500)
  }
}
