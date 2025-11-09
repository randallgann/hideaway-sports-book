# Betting/Offer System Design

**Version**: 1.0
**Date**: November 8, 2025
**Status**: Planning Complete - Ready for Implementation

---

## Table of Contents

1. [Overview](#overview)
2. [Core Concept](#core-concept)
3. [Current State Analysis](#current-state-analysis)
4. [Data Model Design](#data-model-design)
5. [Bet Model Logic](#bet-model-logic)
6. [UI Interaction Design](#ui-interaction-design)
7. [Implementation Phases](#implementation-phases)
8. [Technical Considerations](#technical-considerations)
9. [User Journeys](#user-journeys)
10. [Code Examples](#code-examples)

---

## Overview

This document outlines the design for the betting/offer system - a feature that allows users to place bets on sports games using their bankroll balance. The system builds on the existing game odds syncing and bankroll management infrastructure.

**Key Requirements:**
- Users can click on betting lines to place bets
- Each betting line (offer) tracks total bets placed on it
- Bets lock funds in user's bankroll
- Bets are automatically settled when games complete
- Simple, one-bet-at-a-time workflow
- Free-form amount input

**User Preferences (from discovery):**
- Track total bets per offer only (not per specific bet option)
- Start with console logging for UI interaction testing
- One bet at a time (no shopping cart)
- Free-form number input for bet amounts

**Scale:**
- 10-20 concurrent users
- ~2,000 total users
- No complex caching or scaling needed

---

## Core Concept

### "BettingLine IS the Offer"

The existing `BettingLine` model serves as the "offer" concept. No additional abstraction layer needed.

Each **offer** (BettingLine) has **multiple bet options**:

| Line Type | Bet Options |
|-----------|-------------|
| **Spread** | Home team spread OR Away team spread |
| **Over/Under** | Over OR Under |
| **Moneyline** | Home team win OR Away team win |

**Example:**
```
Spread Offer (BettingLine #123):
├── Option 1: SMU -21.0 (-110 odds) ← User clicks this
└── Option 2: Nevada +21.0 (-110 odds)

Over/Under Offer (BettingLine #124):
├── Option 1: Over 36.0 (-110 odds)
└── Option 2: Under 36.0 (-110 odds) ← User clicks this

Moneyline Offer (BettingLine #125):
├── Option 1: SMU to win (-150 odds)
└── Option 2: Nevada to win (+130 odds)
```

---

## Current State Analysis

### ✅ What We Have

**1. BettingLine Model**
- Stores odds for games (moneyline, spread, over_under)
- Updated automatically via Odds API sync (every 5-60 minutes)
- Fields: `line_type`, `home_odds`, `away_odds`, `spread`, `total`, `over_odds`, `under_odds`

**2. Bankroll System (Fully Functional)**
- `Bankroll` model with locked/available balance tracking
- Transaction history with audit trail
- Ready-to-use methods:
  - `lock_funds_for_bet(amount, bet_id)` - Places bet
  - `settle_bet_win(bet_id, amount, payout)` - Pays out winnings
  - `settle_bet_loss(bet_id, amount)` - Removes losing bet
  - `settle_bet_push(bet_id, amount)` - Returns bet on tie
  - `cancel_bet(bet_id, amount)` - Unlocks funds

**3. Game Display**
- Games page showing all upcoming games
- Betting lines displayed in read-only format
- Mobile-first responsive design with Tailwind CSS

**4. User Authentication**
- Devise with OAuth (Google, GitHub)
- Every user automatically gets a bankroll on signup

### ❌ What's Missing

1. **Bet/Wager Model** - No table to store user bets
2. **Clickable UI** - Betting lines are display-only
3. **Bet Placement Flow** - No forms or actions to place bets
4. **Bet Management** - No "My Bets" page
5. **Settlement System** - No automated bet result determination

---

## Data Model Design

### New `bets` Table

```ruby
create_table :bets do |t|
  # Associations
  t.references :user, null: false, foreign_key: true, index: true
  t.references :game, null: false, foreign_key: true, index: true
  t.references :betting_line, null: false, foreign_key: true  # The "offer"

  # Bet specifics
  t.string :selection, null: false  # "home", "away", "over", "under"
  t.decimal :amount, precision: 10, scale: 2, null: false  # User's wager

  # Odds snapshot (immutable - captured at placement time)
  t.decimal :odds_at_placement, precision: 8, scale: 2, null: false
  t.decimal :line_value_at_placement, precision: 8, scale: 2
    # Stores spread value or total value at placement time

  # Payout calculation
  t.decimal :potential_payout, precision: 10, scale: 2, null: false
  t.decimal :actual_payout, precision: 10, scale: 2

  # Status tracking
  t.string :status, null: false, default: "pending"
    # Values: "pending", "won", "lost", "push", "canceled"
  t.datetime :settled_at
  t.text :settlement_notes

  # Metadata (JSON - store team names, game info for historical display)
  t.text :metadata

  t.timestamps
end

# Indexes for performance
add_index :bets, [:user_id, :status]
add_index :bets, [:game_id, :status]
add_index :bets, :created_at

# Counter cache column on betting_lines
add_column :betting_lines, :bets_count, :integer, default: 0, null: false
```

### Field Explanations

| Field | Purpose |
|-------|---------|
| `selection` | Which bet option: "home", "away", "over", "under" |
| `odds_at_placement` | Snapshot of odds when bet placed (odds change constantly) |
| `line_value_at_placement` | Snapshot of spread or total (also changes) |
| `potential_payout` | Calculated at placement: stake + potential winnings |
| `actual_payout` | Final payout after settlement (won/lost/push) |
| `status` | Bet lifecycle: pending → won/lost/push/canceled |
| `metadata` | JSON storing team names, game details for historical view |
| `bets_count` | Counter cache on BettingLine for "X bets placed" display |

### Why Snapshot Approach?

**Problem:** BettingLines update every 5-60 minutes via automated syncs. If a user places a bet at -110 odds, but the line moves to -120 before settlement, which odds apply?

**Solution:** Snapshot all relevant data at placement time:
- `odds_at_placement` - The exact odds user agreed to
- `line_value_at_placement` - The exact spread/total at that moment
- `metadata` - Team names, game time (in case game is deleted)

**Benefit:** Historical bets remain accurate and fair, even as live data changes.

---

## Bet Model Logic

### Model Definition

```ruby
class Bet < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :game
  belongs_to :betting_line, counter_cache: true  # Auto-maintains bets_count

  # Serialization
  serialize :metadata, JSON

  # Constants
  SELECTIONS = %w[home away over under].freeze
  STATUSES = %w[pending won lost push canceled].freeze

  # Validations
  validates :selection, inclusion: { in: SELECTIONS }
  validates :status, inclusion: { in: STATUSES }
  validates :amount, numericality: { greater_than: 0 }
  validates :odds_at_placement, presence: true

  # Minimum bet amount
  validates :amount, numericality: {
    greater_than_or_equal_to: 5.00,
    message: "must be at least $5.00"
  }

  # Scopes
  scope :pending, -> { where(status: 'pending') }
  scope :settled, -> { where(status: %w[won lost push]) }
  scope :won, -> { where(status: 'won') }
  scope :lost, -> { where(status: 'lost') }
  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :for_game, ->(game_id) { where(game_id: game_id) }
  scope :recent, ->(limit = 10) { order(created_at: :desc).limit(limit) }

  # Callbacks
  before_create :calculate_potential_payout
  before_create :populate_metadata

  # Calculate potential payout from American odds
  def calculate_potential_payout
    if odds_at_placement > 0
      # Underdog: +130 means win $130 on $100 bet
      profit = amount * (odds_at_placement / 100.0)
    else
      # Favorite: -150 means bet $150 to win $100
      profit = amount * (100.0 / odds_at_placement.abs)
    end

    self.potential_payout = amount + profit  # Return stake + winnings
  end

  # Store game/team info for historical display
  def populate_metadata
    self.metadata = {
      game_time: game.game_time,
      sport: game.sport,
      home_team: game.home_team.name,
      away_team: game.away_team.name,
      home_team_abbr: game.home_team.abbreviation,
      away_team_abbr: game.away_team.abbreviation,
      line_type: betting_line.line_type
    }
  end

  # Determine bet result based on final score
  def determine_result
    return nil unless game.status == 'completed'
    return nil unless game.home_score && game.away_score

    case betting_line.line_type
    when 'moneyline'
      check_moneyline_result
    when 'spread'
      check_spread_result
    when 'over_under'
      check_over_under_result
    end
  end

  # Settle bet and update bankroll
  def settle!
    result = determine_result
    return false unless result

    transaction do
      case result
      when 'won'
        settle_win
      when 'lost'
        settle_loss
      when 'push'
        settle_push
      end
    end
  end

  private

  def check_moneyline_result
    return 'push' if game.home_score == game.away_score

    winner = game.home_score > game.away_score ? 'home' : 'away'
    selection == winner ? 'won' : 'lost'
  end

  def check_spread_result
    # Apply spread to selected team's score
    if selection == 'home'
      adjusted_score = game.home_score + line_value_at_placement
      result_score = game.away_score
    else
      adjusted_score = game.away_score - line_value_at_placement
      result_score = game.home_score
    end

    # Check if bet covered the spread
    return 'push' if adjusted_score == result_score
    adjusted_score > result_score ? 'won' : 'lost'
  end

  def check_over_under_result
    total_points = game.home_score + game.away_score

    return 'push' if total_points == line_value_at_placement

    if selection == 'over'
      total_points > line_value_at_placement ? 'won' : 'lost'
    else
      total_points < line_value_at_placement ? 'won' : 'lost'
    end
  end

  def settle_win
    result = user.bankroll.settle_bet_win(id, amount, potential_payout)
    if result[:success]
      update!(
        status: 'won',
        actual_payout: potential_payout,
        settled_at: Time.current,
        settlement_notes: "Bet won - payout: #{potential_payout}"
      )
    end
  end

  def settle_loss
    result = user.bankroll.settle_bet_loss(id, amount)
    if result[:success]
      update!(
        status: 'lost',
        actual_payout: 0,
        settled_at: Time.current,
        settlement_notes: "Bet lost"
      )
    end
  end

  def settle_push
    result = user.bankroll.settle_bet_push(id, amount)
    if result[:success]
      update!(
        status: 'push',
        actual_payout: amount,
        settled_at: Time.current,
        settlement_notes: "Push - stake returned"
      )
    end
  end
end
```

### Updated BettingLine Model

```ruby
class BettingLine < ApplicationRecord
  belongs_to :game
  has_many :bets, dependent: :restrict_with_error
  # Use restrict_with_error to prevent deletion if bets exist

  # Existing validations...
end
```

---

## UI Interaction Design

### Phase 1: Console Logging (Initial Implementation)

**Goal:** Make betting lines clickable and console log bet selection details.

#### Updated View Template

**File:** `app/views/games/index.html.erb`

```erb
<!-- Example for Spread betting line -->
<div class="betting-line-card border border-gray-600 rounded-lg p-4">
  <h3 class="text-sm font-semibold text-gray-400 mb-3">SPREAD</h3>

  <!-- Home team spread option -->
  <div class="bet-option cursor-pointer hover:bg-gray-700 p-3 rounded transition-all mb-2"
       data-controller="bet-selector"
       data-action="click->bet-selector#selectBet"
       data-bet-selector-betting-line-id-value="<%= betting_line.id %>"
       data-bet-selector-game-id-value="<%= game.id %>"
       data-bet-selector-bet-type-value="spread"
       data-bet-selector-selection-value="home"
       data-bet-selector-odds-value="<%= betting_line.home_odds %>"
       data-bet-selector-line-value-value="<%= betting_line.spread %>"
       data-bet-selector-home-team-value="<%= game.home_team.name %>"
       data-bet-selector-away-team-value="<%= game.away_team.name %>">

    <div class="flex justify-between items-center">
      <span class="font-bold text-white">
        <%= game.home_team.abbreviation %> <%= betting_line.spread %>
      </span>
      <span class="<%= betting_line.home_odds < 0 ? 'text-red-400' : 'text-green-400' %>">
        <%= format_odds(betting_line.home_odds) %>
      </span>
    </div>
  </div>

  <!-- Away team spread option -->
  <div class="bet-option cursor-pointer hover:bg-gray-700 p-3 rounded transition-all"
       data-controller="bet-selector"
       data-action="click->bet-selector#selectBet"
       data-bet-selector-betting-line-id-value="<%= betting_line.id %>"
       data-bet-selector-game-id-value="<%= game.id %>"
       data-bet-selector-bet-type-value="spread"
       data-bet-selector-selection-value="away"
       data-bet-selector-odds-value="<%= betting_line.away_odds %>"
       data-bet-selector-line-value-value="<%= betting_line.spread * -1 %>"
       data-bet-selector-home-team-value="<%= game.home_team.name %>"
       data-bet-selector-away-team-value="<%= game.away_team.name %>">

    <div class="flex justify-between items-center">
      <span class="font-bold text-white">
        <%= game.away_team.abbreviation %> <%= betting_line.spread * -1 %>
      </span>
      <span class="<%= betting_line.away_odds < 0 ? 'text-red-400' : 'text-green-400' %>">
        <%= format_odds(betting_line.away_odds) %>
      </span>
    </div>
  </div>

  <!-- Bet count display -->
  <div class="text-sm text-gray-400 mt-3 text-center">
    <%= betting_line.bets_count %> <%= 'bet'.pluralize(betting_line.bets_count) %> placed
  </div>
</div>
```

#### Stimulus Controller

**File:** `app/javascript/controllers/bet_selector_controller.js`

```javascript
import { Controller } from "@hotwired/stimulus"

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

    // Visual feedback
    this.element.classList.add('ring-2', 'ring-green-500', 'bg-gray-700')
    setTimeout(() => {
      this.element.classList.remove('ring-2', 'ring-green-500', 'bg-gray-700')
    }, 300)
  }
}
```

#### Expected Console Output

```javascript
🎲 Bet Option Clicked: {
  offer_id: 123,
  game_id: 456,
  bet_type: "spread",
  selection: "home",
  odds: -110,
  line_value: -21.0,
  home_team: "SMU Mustangs",
  away_team: "Nevada Wolf Pack"
}
```

---

## Implementation Phases

### Phase 1: Foundation & UI Interaction ⭐ START HERE

**Goal:** Make betting lines clickable and console log bet details

**Tasks:**
1. ✅ Create `bets` table migration
2. ✅ Create `Bet` model with validations and associations
3. ✅ Add `bets_count` column to `betting_lines` table (counter cache)
4. ✅ Update `BettingLine` model: `has_many :bets`
5. ✅ Create Stimulus controller (`bet_selector_controller.js`)
6. ✅ Update games index view:
   - Add data attributes to all bet options (spread, moneyline, over/under)
   - Add clickable styling (cursor-pointer, hover effects)
   - Display bets count per offer
7. ✅ Test all bet types and verify console output

**Success Criteria:**
- All betting line options are clickable
- Console logs correct bet data on click
- Visual feedback (ring animation) on click
- Bet counts display correctly (initially 0)

**Files Modified:**
- `db/migrate/TIMESTAMP_create_bets.rb`
- `db/migrate/TIMESTAMP_add_bets_count_to_betting_lines.rb`
- `app/models/bet.rb` (new)
- `app/models/betting_line.rb`
- `app/javascript/controllers/bet_selector_controller.js` (new)
- `app/views/games/index.html.erb`

---

### Phase 2: Bet Placement

**Goal:** Allow users to place real bets with bankroll integration

**Tasks:**
1. Create `BetsController` with `create` action
2. Add routes: `POST /bets`
3. Implement bet placement logic:
   - Validate user is authenticated
   - Validate sufficient bankroll balance
   - Snapshot odds/spread/total at placement time
   - Calculate potential payout
   - Lock funds in bankroll (`bankroll.lock_funds_for_bet`)
   - Create bet record
   - Store metadata (team names, game info)
4. Update Stimulus controller to show bet form
5. Create bet slip partial view
6. Add AJAX/Turbo submission
7. Add bet confirmation (flash message or toast notification)
8. Add minimum bet validation ($5 minimum)
9. Add maximum bet validation (can't exceed available balance)

**Success Criteria:**
- User can click bet option and see bet form
- User can enter amount and submit
- Funds lock in bankroll (available → locked)
- Bet appears in database with correct snapshots
- User receives confirmation message
- Bet count increments on betting line

**Files Created/Modified:**
- `app/controllers/bets_controller.rb` (new)
- `app/views/bets/_bet_slip.html.erb` (new)
- `config/routes.rb`
- `app/javascript/controllers/bet_selector_controller.js`

---

### Phase 3: Bet Display & Management

**Goal:** Users can view their bets and manage pending bets

**Tasks:**
1. Create "My Bets" page (`bets#index`)
2. Create bet detail page (`bets#show`)
3. Display pending bets:
   - Show game details (teams, time)
   - Show bet details (type, selection, amount, odds)
   - Show potential payout
   - Show "Cancel Bet" button (if game not started)
4. Display settled bets:
   - Show result (won/lost/push)
   - Show actual payout
   - Color-code by result (green=won, red=lost, gray=push)
5. Implement bet cancellation:
   - Validate game hasn't started
   - Unlock funds (`bankroll.cancel_bet`)
   - Update bet status to 'canceled'
6. Add navigation link to "My Bets"
7. Add pending bets count badge in navigation
8. Add bet history pagination

**Success Criteria:**
- User can view all their bets (pending and settled)
- Pending bets show potential payout
- Settled bets show result and actual payout
- User can cancel pending bets before game starts
- Clean, mobile-friendly bet history UI

**Files Created/Modified:**
- `app/views/bets/index.html.erb` (new)
- `app/views/bets/show.html.erb` (new)
- `app/controllers/bets_controller.rb`
- `app/views/layouts/application.html.erb` (navigation)
- `config/routes.rb`

---

### Phase 4: Settlement System

**Goal:** Automatically settle bets when games complete

**Tasks:**
1. Implement bet result determination logic in `Bet#determine_result`:
   - Moneyline: Check winner
   - Spread: Check if spread covered
   - Over/Under: Check if total exceeded
   - Handle pushes (ties)
2. Implement `Bet#settle!` method
3. Create `SettleBetsJob` background job
4. Add job to recurring schedule:
   - Run every 15 minutes
   - Find completed games with pending bets
   - Settle each bet
5. Test settlement logic with sample data
6. Add settlement notifications:
   - Flash message when user views settled bet
   - Optional: Email notification (future)
7. Add manual settlement UI for admins (edge cases)
8. Add settlement audit log

**Success Criteria:**
- Bets automatically settle when game completes
- Correct results (won/lost/push) determined
- Bankroll correctly updated:
  - Won: locked → available + winnings
  - Lost: locked → removed
  - Push: locked → available (returned)
- Background job runs reliably
- Settlement can be triggered manually if needed

**Files Created/Modified:**
- `app/jobs/settle_bets_job.rb` (new)
- `config/recurring.yml`
- `app/models/bet.rb`
- `test/jobs/settle_bets_job_test.rb` (new)

---

## Technical Considerations

### 1. Odds Snapshot Strategy

**Problem:** BettingLines update every 5-60 minutes via API sync. Odds can change between bet placement and settlement.

**Solution:** Snapshot all relevant data at placement time:
```ruby
# In Bet model before_create callback
def snapshot_odds
  case betting_line.line_type
  when 'moneyline'
    self.odds_at_placement = selection == 'home' ?
      betting_line.home_odds : betting_line.away_odds
  when 'spread'
    self.odds_at_placement = selection == 'home' ?
      betting_line.home_odds : betting_line.away_odds
    self.line_value_at_placement = betting_line.spread
  when 'over_under'
    self.odds_at_placement = selection == 'over' ?
      betting_line.over_odds : betting_line.under_odds
    self.line_value_at_placement = betting_line.total
  end
end
```

**Benefit:** Bet remains fair regardless of line movement. User gets the odds they agreed to.

---

### 2. Counter Cache Performance

**Problem:** Displaying "X bets placed" on every betting line requires expensive COUNT queries.

**Solution:** Use Rails counter cache:

```ruby
# In Bet model
belongs_to :betting_line, counter_cache: true

# In view (no query needed!)
<%= betting_line.bets_count %> bets placed
```

**Benefit:** Fast lookups, no N+1 queries, automatically maintained by Rails.

---

### 3. American Odds Conversion

**Understanding American Odds:**
- **Negative** (e.g., -150): Favorite - bet $150 to win $100
- **Positive** (e.g., +130): Underdog - bet $100 to win $130

**Conversion Formula:**
```ruby
def calculate_profit(amount, odds)
  if odds > 0
    # Underdog: profit = amount * (odds / 100)
    amount * (odds / 100.0)
  else
    # Favorite: profit = amount * (100 / |odds|)
    amount * (100.0 / odds.abs)
  end
end

def calculate_payout(amount, odds)
  calculate_profit(amount, odds) + amount  # profit + original stake
end
```

**Examples:**
```ruby
# Bet $100 on -150 (favorite)
profit = 100 * (100 / 150) = $66.67
payout = $166.67 (stake + profit)

# Bet $100 on +130 (underdog)
profit = 100 * (130 / 100) = $130.00
payout = $230.00 (stake + profit)

# Bet $50 on -110 (common spread/over-under odds)
profit = 50 * (100 / 110) = $45.45
payout = $95.45
```

---

### 4. Data Integrity & Transactions

**Use database transactions for critical operations:**

```ruby
def place_bet(user, betting_line, selection, amount)
  ActiveRecord::Base.transaction do
    # 1. Lock funds
    result = user.bankroll.lock_funds_for_bet(amount, bet_id)
    raise ActiveRecord::Rollback unless result[:success]

    # 2. Create bet
    bet = user.bets.create!(
      game: game,
      betting_line: betting_line,
      selection: selection,
      amount: amount
    )

    # If anything fails, entire transaction rolls back
    bet
  end
end
```

**Prevent data inconsistencies:**
- Lock funds BEFORE creating bet
- Use foreign key constraints
- Prevent deletion of betting lines with bets (`dependent: :restrict_with_error`)
- Validate game hasn't started before allowing bets

---

### 5. Settlement Logic

**Moneyline:**
```ruby
def check_moneyline_result
  return 'push' if game.home_score == game.away_score  # Tie (rare)

  winner = game.home_score > game.away_score ? 'home' : 'away'
  selection == winner ? 'won' : 'lost'
end
```

**Spread:**
```ruby
def check_spread_result
  # Example: User bets Home -7.5
  # Home wins 28-20 (wins by 8) → bet WINS (covered spread)
  # Home wins 28-21 (wins by 7) → bet LOSES (didn't cover)

  if selection == 'home'
    margin = game.home_score - game.away_score
    adjusted_margin = margin + line_value_at_placement  # e.g., 8 + (-7.5) = 0.5
  else
    margin = game.away_score - game.home_score
    adjusted_margin = margin - line_value_at_placement
  end

  return 'push' if adjusted_margin == 0
  adjusted_margin > 0 ? 'won' : 'lost'
end
```

**Over/Under:**
```ruby
def check_over_under_result
  total_points = game.home_score + game.away_score

  # Exact match = push
  return 'push' if total_points == line_value_at_placement

  if selection == 'over'
    total_points > line_value_at_placement ? 'won' : 'lost'
  else
    total_points < line_value_at_placement ? 'won' : 'lost'
  end
end
```

---

### 6. Background Job Strategy

**Job:** `SettleBetsJob`

```ruby
class SettleBetsJob < ApplicationJob
  queue_as :default

  def perform
    # Find completed games with unsettled bets
    game_ids = Bet.pending.distinct.pluck(:game_id)

    Game.where(id: game_ids, status: 'completed')
        .where.not(home_score: nil)
        .where.not(away_score: nil)
        .find_each do |game|

      settle_game_bets(game)
    end
  end

  private

  def settle_game_bets(game)
    game.bets.pending.find_each do |bet|
      bet.settle!
    rescue => e
      Rails.logger.error("Failed to settle bet #{bet.id}: #{e.message}")
      # Continue processing other bets
    end
  end
end
```

**Scheduling** (`config/recurring.yml`):
```yaml
settle_bets:
  class: SettleBetsJob
  schedule: every 15 minutes
  queue: default
```

**For small scale (10-20 users):**
- Solid Queue is sufficient (no Sidekiq needed)
- 15-minute frequency is fine (games update gradually)
- Simple error handling (log and continue)

---

### 7. Validation Rules

**Bet Amount Validations:**
```ruby
# In Bet model
validates :amount, numericality: {
  greater_than_or_equal_to: 5.00,
  message: "must be at least $5.00"
}

validate :amount_does_not_exceed_balance

def amount_does_not_exceed_balance
  return unless user && amount

  if amount > user.bankroll.available_balance
    errors.add(:amount, "exceeds available balance ($#{user.bankroll.available_balance})")
  end
end
```

**Game State Validations:**
```ruby
validate :game_has_not_started

def game_has_not_started
  if game && game.game_time < Time.current
    errors.add(:base, "Cannot place bet on game that has already started")
  end
end
```

---

### 8. Security Considerations

**Controller Authorization:**
```ruby
class BetsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_bet, only: [:show, :cancel]

  def set_bet
    @bet = current_user.bets.find(params[:id])
    # Ensures users can only access their own bets
  end
end
```

**Prevent Double Betting:**
```ruby
# Optional: Prevent duplicate bets on same game/line/selection
validates :betting_line_id, uniqueness: {
  scope: [:user_id, :selection, :status],
  conditions: -> { where(status: 'pending') },
  message: "already has a pending bet for this selection"
}
```

---

## User Journeys

### Journey 1: Place First Bet (Happy Path)

```
1. User signs in (has $1000 bankroll from initial deposit)
2. Visits /games (homepage)
3. Sees upcoming NFL game: "Chiefs @ Bills"
4. Expands NFL section, views betting lines
5. Clicks "Bills -3.5 (-110)" spread option
6. [Phase 1] Console logs bet data ✅
7. [Phase 2] Bet slip form appears
8. User enters $50
9. System shows: "Potential payout: $95.45"
10. User clicks "Place Bet"
11. Funds lock: Available $1000 → $950, Locked $0 → $50
12. Success message: "Bet placed successfully!"
13. Bet count updates: "0 bets" → "1 bet placed"
14. [Phase 3] Navigates to "My Bets"
15. Sees pending bet with details
16. Game starts, user watches
17. Game ends: Bills win 24-20 (win by 4, covered -3.5 spread)
18. [Phase 4] Background job settles bet (15 min later)
19. Bet status: Pending → Won
20. Bankroll update: Locked $50 → $0, Available $950 → $1045.45
21. User sees "Won" badge on bet, profit: +$45.45
```

---

### Journey 2: Cancel Bet Before Game

```
1. User places bet on Over 45.5 for tonight's game
2. Funds lock: $100 moved to locked balance
3. Later, changes mind
4. Visits "My Bets" page
5. Clicks "Cancel Bet" button
6. Confirmation: "Are you sure?"
7. Confirms cancellation
8. Bankroll.cancel_bet called
9. Funds unlock: Locked $100 → $0, Available +$100
10. Bet status: Pending → Canceled
11. Success message: "Bet canceled, funds returned"
```

---

### Journey 3: Losing Bet

```
1. User bets $75 on Packers moneyline (+150)
2. Potential payout: $187.50 (profit: $112.50)
3. Funds lock: Available -$75, Locked +$75
4. Game ends: Packers lose 21-28
5. Background job settles bet
6. Bankroll.settle_bet_loss called
7. Funds removed: Locked $75 → $0 (no return to available)
8. Bet status: Pending → Lost
9. Actual payout: $0
10. User views "My Bets": Red "Lost" badge, -$75
```

---

### Journey 4: Push (Tie)

```
1. User bets $50 on Over 42.0
2. Game ends: 21-21 (total: 42 exactly)
3. Background job determines result: Push
4. Bankroll.settle_bet_push called
5. Stake returned: Locked $50 → $0, Available +$50
6. Bet status: Pending → Push
7. Actual payout: $50 (stake only, no profit)
8. User views bet: Gray "Push" badge, "Stake returned"
```

---

## Code Examples

### Example 1: Helper Method for Odds Formatting

**File:** `app/helpers/betting_helper.rb`

```ruby
module BettingHelper
  def format_odds(odds)
    return 'N/A' if odds.nil?

    odds > 0 ? "+#{odds}" : odds.to_s
  end

  def odds_color_class(odds)
    return 'text-gray-400' if odds.nil?

    odds < 0 ? 'text-red-400' : 'text-green-400'
  end

  def format_currency(amount)
    number_to_currency(amount, precision: 2)
  end

  def bet_status_badge_class(status)
    case status
    when 'won'
      'bg-green-600 text-white'
    when 'lost'
      'bg-red-600 text-white'
    when 'push'
      'bg-gray-600 text-white'
    when 'pending'
      'bg-yellow-600 text-white'
    when 'canceled'
      'bg-gray-500 text-white'
    else
      'bg-gray-400 text-white'
    end
  end
end
```

---

### Example 2: BetsController (Phase 2)

**File:** `app/controllers/bets_controller.rb`

```ruby
class BetsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_bet, only: [:show, :cancel]

  def index
    @pending_bets = current_user.bets.pending
                                .includes(game: [:home_team, :away_team])
                                .order(created_at: :desc)

    @settled_bets = current_user.bets.settled
                                .includes(game: [:home_team, :away_team])
                                .order(settled_at: :desc)
                                .limit(20)
  end

  def show
    # @bet set by before_action
  end

  def create
    @game = Game.find(params[:game_id])
    @betting_line = @game.betting_lines.find(params[:betting_line_id])

    # Validate game hasn't started
    if @game.game_time < Time.current
      render json: {
        success: false,
        message: "Cannot bet on game that has already started"
      }, status: :unprocessable_entity
      return
    end

    # Build bet
    @bet = current_user.bets.new(bet_params)
    @bet.game = @game
    @bet.betting_line = @betting_line
    @bet.snapshot_odds  # Callback sets odds_at_placement

    # Attempt to place bet (locks funds)
    ActiveRecord::Base.transaction do
      result = current_user.bankroll.lock_funds_for_bet(@bet.amount, @bet.id)

      unless result[:success]
        render json: {
          success: false,
          message: result[:message]
        }, status: :unprocessable_entity
        raise ActiveRecord::Rollback
      end

      if @bet.save
        render json: {
          success: true,
          message: "Bet placed successfully!",
          bet_id: @bet.id,
          potential_payout: @bet.potential_payout
        }
      else
        render json: {
          success: false,
          message: @bet.errors.full_messages.join(", ")
        }, status: :unprocessable_entity
        raise ActiveRecord::Rollback
      end
    end
  end

  def cancel
    if @bet.status != 'pending'
      flash[:alert] = "Can only cancel pending bets"
      redirect_to bets_path and return
    end

    if @bet.game.game_time < Time.current
      flash[:alert] = "Cannot cancel bet after game has started"
      redirect_to bet_path(@bet) and return
    end

    result = current_user.bankroll.cancel_bet(@bet.id, @bet.amount)

    if result[:success]
      @bet.update!(status: 'canceled')
      flash[:notice] = "Bet canceled successfully - funds returned"
    else
      flash[:alert] = result[:message]
    end

    redirect_to bets_path
  end

  private

  def set_bet
    @bet = current_user.bets.find(params[:id])
  end

  def bet_params
    params.require(:bet).permit(:selection, :amount)
  end
end
```

---

### Example 3: Routes Configuration

**File:** `config/routes.rb`

```ruby
Rails.application.routes.draw do
  # Existing routes...
  devise_for :users, controllers: { omniauth_callbacks: 'users/omniauth_callbacks' }

  resources :games, only: [:index]

  resource :bankroll, only: [:show] do
    post :deposit
    post :withdraw
  end

  # New betting routes
  resources :bets, only: [:index, :show, :create] do
    member do
      post :cancel
    end
  end

  root "games#index"
end
```

---

### Example 4: Migration Files

**File:** `db/migrate/TIMESTAMP_create_bets.rb`

```ruby
class CreateBets < ActiveRecord::Migration[8.0]
  def change
    create_table :bets do |t|
      t.references :user, null: false, foreign_key: true
      t.references :game, null: false, foreign_key: true
      t.references :betting_line, null: false, foreign_key: true

      t.string :selection, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false

      t.decimal :odds_at_placement, precision: 8, scale: 2, null: false
      t.decimal :line_value_at_placement, precision: 8, scale: 2

      t.decimal :potential_payout, precision: 10, scale: 2, null: false
      t.decimal :actual_payout, precision: 10, scale: 2

      t.string :status, null: false, default: 'pending'
      t.datetime :settled_at
      t.text :settlement_notes

      t.text :metadata

      t.timestamps
    end

    add_index :bets, [:user_id, :status]
    add_index :bets, [:game_id, :status]
    add_index :bets, :created_at
  end
end
```

**File:** `db/migrate/TIMESTAMP_add_bets_count_to_betting_lines.rb`

```ruby
class AddBetsCountToBettingLines < ActiveRecord::Migration[8.0]
  def change
    add_column :betting_lines, :bets_count, :integer, default: 0, null: false

    # Optional: Reset counter cache for existing records
    reversible do |dir|
      dir.up do
        BettingLine.find_each do |betting_line|
          BettingLine.reset_counters(betting_line.id, :bets)
        end
      end
    end
  end
end
```

---

## Next Steps

### Immediate Actions (Phase 1)

1. ✅ Review and approve this design document
2. ✅ Create feature branch: `feature/betting-offer-system`
3. ✅ Run migrations to create `bets` table
4. ✅ Create `Bet` model with basic validations
5. ✅ Add Stimulus controller for bet selection
6. ✅ Update games view with clickable betting lines
7. ✅ Test console logging for all bet types

### Future Enhancements (Post-Phase 4)

- **Parlay Bets**: Combine multiple bets with higher payouts
- **Live Betting**: Allow bets during games (requires more frequent odds updates)
- **Bet Limits**: Daily/weekly betting limits for responsible gambling
- **Leaderboards**: Show top winners, biggest payouts
- **Bet Sharing**: Share bet slips with friends
- **Bet Analytics**: Win/loss charts, ROI tracking
- **Push Notifications**: Alert users when bets settle
- **Mobile App**: Native iOS/Android apps

---

## Glossary

| Term | Definition |
|------|------------|
| **Offer** | A betting line (spread/moneyline/over-under) that users can bet on |
| **Bet Option** | One side of an offer (e.g., "Home -3.5" or "Away +3.5") |
| **Selection** | The user's choice within an offer ("home", "away", "over", "under") |
| **Stake** | The amount wagered by the user |
| **Odds** | American odds format (negative = favorite, positive = underdog) |
| **Potential Payout** | Stake + potential winnings (calculated at placement) |
| **Actual Payout** | Final payout after settlement (won/lost/push) |
| **Locked Balance** | Funds tied up in pending bets |
| **Available Balance** | Funds available for new bets |
| **Push** | Tie result (stake returned, no profit) |
| **Cover** | When a spread bet wins (team beats the spread) |
| **Snapshot** | Capturing odds/lines at bet placement time |

---

## References

- **CLAUDE.md**: Project development guidelines
- **Bankroll Model**: `app/models/bankroll.rb` - Settlement methods
- **Odds API**: `app/services/odds_api/` - API integration
- **Solid Queue**: Background job processing
- **Devise**: User authentication
- **Tailwind CSS**: UI styling framework

---

**Document Version History:**
- v1.0 (2025-11-08): Initial design document created
