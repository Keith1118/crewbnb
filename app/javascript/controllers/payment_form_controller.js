import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submitButton", "submitText", "submitSpinner"]
  static values = {
    clientSecret: String,
    publishableKey: String,
    returnUrl: String
  }

  connect() {
    this.stripe = Stripe(this.publishableKeyValue)
    this.elements = this.stripe.elements({
      clientSecret: this.clientSecretValue,
      appearance: {
        theme: "stripe",
        variables: {
          colorPrimary: "#001949",
          borderRadius: "12px",
          fontFamily: "Inter, system-ui, sans-serif"
        }
      }
    })

    this.paymentElement = this.elements.create("payment")
    this.paymentElement.mount("#payment-element")
  }

  async submit(event) {
    event.preventDefault()
    this.setLoading(true)

    // Clear previous errors
    const errorEl = document.getElementById("payment-errors")
    errorEl.textContent = ""

    const { error } = await this.stripe.confirmPayment({
      elements: this.elements,
      confirmParams: {
        return_url: this.returnUrlValue
      }
    })

    // This point is only reached if there is an immediate error.
    // On success, the customer is redirected to the return_url.
    if (error) {
      if (error.type === "card_error" || error.type === "validation_error") {
        errorEl.textContent = error.message
      } else {
        errorEl.textContent = "An unexpected error occurred. Please try again."
      }
      this.setLoading(false)
    }
  }

  setLoading(loading) {
    this.submitButtonTarget.disabled = loading
    if (loading) {
      this.submitTextTarget.classList.add("hidden")
      this.submitSpinnerTarget.classList.remove("hidden")
    } else {
      this.submitTextTarget.classList.remove("hidden")
      this.submitSpinnerTarget.classList.add("hidden")
    }
  }
}
