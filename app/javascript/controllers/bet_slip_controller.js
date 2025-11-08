import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="bet-slip"
export default class extends Controller {
  static targets = [
    "container",
    "gameInfo",
    "betDescription",
    "odds",
    "amountInput",
    "potentialPayout",
    "potentialProfit",
    "errorMessage",
    "submitButton",
    "loading",
    "form"
  ]

  connect() {
    // Store bet data when modal is opened
    this.betData = {}
  }

  open(betData) {
    // Store bet data
    this.betData = betData

    // Populate modal with bet details
    this.gameInfoTarget.textContent = `${betData.away_team} @ ${betData.home_team}`
    this.betDescriptionTarget.textContent = this.formatBetDescription(betData)
    this.oddsTarget.textContent = this.formatOdds(betData.odds)

    // Show the modal
    this.element.classList.remove('hidden')

    // Focus on amount input
    setTimeout(() => this.amountInputTarget.focus(), 100)
  }

  close() {
    this.element.classList.add('hidden')
    this.resetForm()
  }

  closeOnBackdrop(event) {
    // Only close if clicking the backdrop, not the modal content
    if (event.target === this.element) {
      this.close()
    }
  }

  stopPropagation(event) {
    event.stopPropagation()
  }

  formatBetDescription(betData) {
    const { bet_type, selection, line_value, home_team, away_team } = betData

    switch (bet_type) {
      case 'moneyline':
        return `${selection === 'home' ? home_team : away_team} to Win`

      case 'spread':
        const team = selection === 'home' ? home_team : away_team
        return `${team} ${line_value > 0 ? '+' : ''}${line_value}`

      case 'over_under':
        return `${selection === 'over' ? 'Over' : 'Under'} ${line_value}`

      default:
        return 'Unknown bet type'
    }
  }

  formatOdds(odds) {
    return odds > 0 ? `+${odds}` : `${odds}`
  }

  calculatePayout() {
    const amount = parseFloat(this.amountInputTarget.value) || 0
    const odds = this.betData.odds

    if (amount <= 0) {
      this.potentialPayoutTarget.textContent = '$0.00'
      this.potentialProfitTarget.textContent = '$0.00'
      return
    }

    // Calculate profit based on American odds
    let profit
    if (odds > 0) {
      // Underdog: +130 means win $130 on $100 bet
      profit = amount * (odds / 100.0)
    } else {
      // Favorite: -150 means bet $150 to win $100
      profit = amount * (100.0 / Math.abs(odds))
    }

    const payout = amount + profit

    this.potentialPayoutTarget.textContent = `$${payout.toFixed(2)}`
    this.potentialProfitTarget.textContent = `$${profit.toFixed(2)}`
  }

  async submitBet(event) {
    event.preventDefault()

    const amount = parseFloat(this.amountInputTarget.value)

    if (!amount || amount < 5) {
      this.showError('Minimum bet amount is $5.00')
      return
    }

    // Hide error message
    this.errorMessageTarget.classList.add('hidden')

    // Show loading state
    this.loadingTarget.classList.remove('hidden')
    this.submitButtonTarget.disabled = true

    try {
      const response = await fetch('/bets', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.getCSRFToken()
        },
        body: JSON.stringify({
          game_id: this.betData.game_id,
          betting_line_id: this.betData.offer_id,
          selection: this.betData.selection,
          amount: amount
        })
      })

      const data = await response.json()

      if (data.success) {
        // Success! Show success message and close modal
        this.showSuccessNotification(data.message)
        this.close()

        // Refresh the page to update bet counts and bankroll
        // In a more sophisticated app, we'd use Turbo Streams
        setTimeout(() => window.location.reload(), 500)
      } else {
        // Show error message
        this.showError(data.message)
      }
    } catch (error) {
      console.error('Error placing bet:', error)
      this.showError('An error occurred while placing your bet. Please try again.')
    } finally {
      // Hide loading state
      this.loadingTarget.classList.add('hidden')
      this.submitButtonTarget.disabled = false
    }
  }

  showError(message) {
    this.errorMessageTarget.querySelector('p').textContent = message
    this.errorMessageTarget.classList.remove('hidden')
  }

  showSuccessNotification(message) {
    // Create a simple toast notification
    const toast = document.createElement('div')
    toast.className = 'fixed top-4 right-4 bg-green-600 text-white px-6 py-3 rounded-lg shadow-lg z-50 animate-fade-in'
    toast.textContent = message

    document.body.appendChild(toast)

    // Remove after 3 seconds
    setTimeout(() => {
      toast.classList.add('animate-fade-out')
      setTimeout(() => toast.remove(), 300)
    }, 3000)
  }

  getCSRFToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }

  resetForm() {
    this.amountInputTarget.value = ''
    this.potentialPayoutTarget.textContent = '$0.00'
    this.potentialProfitTarget.textContent = '$0.00'
    this.errorMessageTarget.classList.add('hidden')
  }
}
