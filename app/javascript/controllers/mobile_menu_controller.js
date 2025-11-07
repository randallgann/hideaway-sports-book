import { Controller } from "@hotwired/stimulus"

// Mobile menu controller for toggling navigation on mobile devices
export default class extends Controller {
  static targets = ["menu"]

  toggle() {
    this.menuTarget.classList.toggle("hidden")
  }

  // Close menu when clicking outside
  close(event) {
    if (!this.element.contains(event.target)) {
      this.menuTarget.classList.add("hidden")
    }
  }

  // Close menu on escape key
  closeOnEscape(event) {
    if (event.key === "Escape") {
      this.menuTarget.classList.add("hidden")
    }
  }

  connect() {
    // Add event listeners for closing menu
    document.addEventListener("click", this.close.bind(this))
    document.addEventListener("keydown", this.closeOnEscape.bind(this))
  }

  disconnect() {
    // Clean up event listeners
    document.removeEventListener("click", this.close.bind(this))
    document.removeEventListener("keydown", this.closeOnEscape.bind(this))
  }
}
