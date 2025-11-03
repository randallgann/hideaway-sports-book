import { Controller } from "@hotwired/stimulus"

// Handles collapsible sport sections
// Usage: data-controller="collapsible" on container element
export default class extends Controller {
  static targets = ["content", "arrow"]

  connect() {
    // Ensure content starts hidden
    this.contentTarget.style.display = "none"
  }

  toggle() {
    const isHidden = this.contentTarget.style.display === "none"

    if (isHidden) {
      this.contentTarget.style.display = "block"
      this.arrowTarget.style.transform = "rotate(90deg)"
      this.arrowTarget.setAttribute("aria-expanded", "true")
    } else {
      this.contentTarget.style.display = "none"
      this.arrowTarget.style.transform = "rotate(0deg)"
      this.arrowTarget.setAttribute("aria-expanded", "false")
    }
  }
}
