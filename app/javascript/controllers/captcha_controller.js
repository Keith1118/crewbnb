import { Controller } from "@hotwired/stimulus"

// Renders the Cloudflare Turnstile widget. Turnstile's automatic mode scans the
// document once, when its script loads, so after a Turbo visit the container
// would stay empty and every submission would arrive without a token — hence
// explicit rendering on connect.

const SCRIPT_URL = "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit"
let scriptPromise = null

function loadTurnstile() {
  if (window.turnstile) return Promise.resolve()

  scriptPromise ||= new Promise((resolve, reject) => {
    const script = document.createElement("script")
    script.src = SCRIPT_URL
    script.async = true
    script.onload = resolve
    script.onerror = () => {
      scriptPromise = null // let a later form try again
      reject(new Error("Turnstile script failed to load"))
    }
    document.head.appendChild(script)
  })

  return scriptPromise
}

export default class extends Controller {
  static values = { sitekey: String }

  connect() {
    loadTurnstile()
      .then(() => {
        // The form can be gone by the time the script lands.
        if (!this.element.isConnected) return
        this.widgetId = window.turnstile.render(this.element, { sitekey: this.sitekeyValue })
      })
      .catch((error) => console.error(error))
  }

  disconnect() {
    if (this.widgetId !== undefined) window.turnstile?.remove(this.widgetId)
  }
}
