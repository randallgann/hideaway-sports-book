import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="bet-selector"
export default class extends Controller {
  static values = {
    bettingLineId: Number,
    gameId: Number,
    betType: String,
    selection: String,
    odds: Number,
    lineValue: Number,
    homeTeam: String,
    awayTeam: String
  }

  selectBet(event) {
    event.preventDefault()

    const betData = {
      offer_id: this.bettingLineIdValue,
      game_id: this.gameIdValue,
      bet_type: this.betTypeValue,
      selection: this.selectionValue,
      odds: this.oddsValue,
      line_value: this.lineValueValue,
      home_team: this.homeTeamValue,
      away_team: this.awayTeamValue
    }

    console.log('🎲 Bet Option Clicked:', betData)

    // Visual feedback - brief highlight animation
    this.element.classList.add('ring-2', 'ring-green-500', 'bg-gray-700')
    setTimeout(() => {
      this.element.classList.remove('ring-2', 'ring-green-500', 'bg-gray-700')
    }, 300)

    // Open bet slip modal
    const betSlipController = this.application.getControllerForElementAndIdentifier(
      document.querySelector('[data-controller="bet-slip"]'),
      'bet-slip'
    )

    if (betSlipController) {
      betSlipController.open(betData)
    }
  }
}
