import { Controller } from "@hotwired/stimulus"

// Shows the company-only fields when the "Company" applicant type is selected,
// and hides (plus disables, so they aren't submitted) them otherwise.
export default class extends Controller {
  static targets = ["company"]

  connect() {
    this.toggle()
  }

  toggle() {
    const selected = this.element.querySelector('input[name="host_application[applicant_type]"]:checked')
    const isCompany = selected && selected.value === "company"

    this.companyTargets.forEach((el) => {
      el.classList.toggle("hidden", !isCompany)
      el.querySelectorAll("input, select, textarea").forEach((field) => {
        field.disabled = !isCompany
      })
    })
  }
}
