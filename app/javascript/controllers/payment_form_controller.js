import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submitButton", "submitText", "submitSpinner"]
  static values = {
    clientSecret: String,
    publishableKey: String,
    returnUrl: String,
    // "payment" charges the card now; "setup" only saves it for a later,
    // off-session charge. Same Element, different confirm call.
    mode: { type: String, default: "payment" }
  }

  connect() {
    // A failure here used to be silent: no card fields, no message, and a submit
    // button that span forever because this.stripe was never assigned.
    try {
      this.mount()
    } catch (error) {
      this.showFatal(error)
    }
  }

  showFatal(error) {
    const errorEl = document.getElementById("payment-errors")
    if (errorEl) {
      errorEl.textContent = `Payment form failed to load: ${error?.message || error}. Please refresh, or contact us if it keeps happening.`
    }
    if (this.hasSubmitButtonTarget) this.submitButtonTarget.disabled = true
    console.error("Stripe payment form failed to initialise", error)
  }

  mount() {
    if (typeof Stripe === "undefined") throw new Error("Stripe.js did not load")
    if (!this.publishableKeyValue) throw new Error("missing publishable key")
    if (!this.clientSecretValue) throw new Error("missing client secret")

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

    // Never spin against a form that never loaded.
    if (!this.stripe || !this.elements) {
      this.showFatal(new Error("the card form isn't ready"))
      return
    }

    this.setLoading(true)

    // Clear previous errors
    const errorEl = document.getElementById("payment-errors")
    errorEl.textContent = ""

    const confirmParams = { return_url: this.returnUrlValue }
    const { error } = this.modeValue === "setup"
      ? await this.stripe.confirmSetup({ elements: this.elements, confirmParams })
      : await this.stripe.confirmPayment({ elements: this.elements, confirmParams })

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
