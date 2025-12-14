# feat: Automatic $5000 Bankroll & Remove Deposit/Withdraw UI

**Created:** 2025-12-14
**Type:** Enhancement
**Priority:** High (Production Readiness)

## Overview

Transition from POC to production by:
1. Automatically giving each new user $5,000 in play money upon registration
2. Removing the deposit/withdraw **UI elements only** (keep backend functionality for future use)
3. Aligning the app behavior with the FAQ documentation

This change enforces the "paper betting" concept where all users start equal and compete purely on betting skill.

## Problem Statement / Motivation

**Current State (POC):**
- Users register with $0 bankroll balance
- Users can manually deposit/withdraw funds via `/bankroll` page UI
- This contradicts the FAQ which states users receive $5,000 to start

**Desired State (Production):**
- New users automatically receive $5,000 upon registration
- No deposit/withdraw forms visible in UI
- Backend functionality preserved for future admin/API use
- Bankroll page shows balance and transaction history only
- App behavior matches FAQ documentation

## Proposed Solution

### High-Level Approach

1. **Modify User callback** to create bankroll with $5,000 initial balance
2. **Remove UI elements** for deposit/withdraw forms from the view
3. **Keep routes, controller actions, and model methods** for future use

### What Changes vs. What Stays

| Component | Action | Reason |
|-----------|--------|--------|
| `Bankroll::INITIAL_BALANCE` | **Add** | Define the $5,000 constant |
| `User#create_default_bankroll` | **Modify** | Set initial balance to $5,000 |
| Deposit/withdraw routes | **Keep** | Future admin/API use |
| Deposit/withdraw controller actions | **Keep** | Future admin/API use |
| Deposit/withdraw model methods | **Keep** | Used by controller, future use |
| Deposit/withdraw UI forms | **Remove** | Users shouldn't access manually |
| Business constants (MIN_DEPOSIT, etc.) | **Keep** | May be needed for future features |

## Technical Approach

### Files to Modify

| File | Change Type | Description |
|------|-------------|-------------|
| `app/models/bankroll.rb:11` | Add | Add `INITIAL_BALANCE = 5000.00` constant |
| `app/models/user.rb:37-39` | Modify | Update `create_default_bankroll` to use initial balance |
| `app/views/bankrolls/show.html.erb:34-112` | Remove | Remove deposit and withdraw form sections only |

### Files NOT Changed (Preserved for Future)

| File | Reason to Keep |
|------|----------------|
| `config/routes.rb:15-16` | Admin/API may need deposit/withdraw endpoints |
| `app/controllers/bankrolls_controller.rb:9-45` | Controller actions remain functional |
| `app/models/bankroll.rb` (methods) | All model methods preserved |

## Implementation Details

### 1. Add Initial Balance Constant

```ruby
# app/models/bankroll.rb (add after line 10)
INITIAL_BALANCE = 5000.00
```

### 2. Update User Callback

```ruby
# app/models/user.rb:37-39
def create_default_bankroll
  create_bankroll!(
    currency: 'USD',
    available_balance: Bankroll::INITIAL_BALANCE
  )
end
```

### 3. Update View (Remove UI Only)

Remove from `app/views/bankrolls/show.html.erb`:
- Deposit form card (lines 34-72)
- Withdraw form card (lines 75-112)

Add informational message in their place:
```erb
<!-- Info Message (replaces deposit/withdraw forms) -->
<div class="bg-blue-50 border border-blue-200 rounded-lg p-4 sm:p-5" style="margin-bottom: 1.5rem;">
  <p class="text-blue-800 text-sm sm:text-base">
    All players start with <strong class="text-[#4CAF50]">$5,000</strong> in play money.
    Your bankroll changes based on your betting results. Good luck!
  </p>
</div>
```

Update empty state message:
```erb
<!-- FROM -->
<p>No transactions yet. Make your first deposit to get started!</p>

<!-- TO -->
<p>No transactions yet. Place your first bet to get started!</p>
```

## Acceptance Criteria

### Functional Requirements

- [ ] New users (email registration) receive $5,000 bankroll automatically
- [ ] New users (Google OAuth) receive $5,000 bankroll automatically
- [ ] New users (GitHub OAuth) receive $5,000 bankroll automatically
- [ ] `/bankroll` page displays balance **without** deposit/withdraw forms
- [ ] `/bankroll` page shows informational message about $5,000 starting balance
- [ ] Transaction history continues to display correctly
- [ ] Betting system continues to work (lock funds, settle bets)
- [ ] Backend routes `/bankroll/deposit` and `/bankroll/withdraw` still functional (for future use)

### Non-Functional Requirements

- [ ] No database migration required
- [ ] Existing users retain their current balance
- [ ] All backend functionality preserved
- [ ] All existing tests pass

## Data Migration Decision

**Decision:** Do NOT backfill existing users.

**Rationale:**
- This is a learning/casual project per CLAUDE.md
- Existing users can continue with their current balance
- New behavior only applies to new registrations
- Simplifies deployment and reduces risk

## MVP Implementation

### app/models/bankroll.rb

```ruby
class Bankroll < ApplicationRecord
  belongs_to :user
  has_many :bankroll_transactions, dependent: :destroy

  validates :user_id, presence: true, uniqueness: true
  validates :currency, presence: true
  validates :available_balance, :locked_balance, numericality: { greater_than_or_equal_to: 0 }
  validates :payment_processor, presence: true

  # Initial balance for new users (paper trading)
  INITIAL_BALANCE = 5000.00

  # Business rules (kept for future use)
  MIN_DEPOSIT = 10.00
  MIN_WITHDRAWAL = 20.00
  MAX_TRANSACTION = 10_000.00

  # ... rest of existing code unchanged ...
end
```

### app/models/user.rb

```ruby
private

def create_default_bankroll
  create_bankroll!(
    currency: 'USD',
    available_balance: Bankroll::INITIAL_BALANCE
  )
end
```

### app/views/bankrolls/show.html.erb

```erb
<div class="w-full">
  <h1 class="text-2xl sm:text-3xl font-bold text-gray-800" style="margin-bottom: 1.5rem;">Your Bankroll</h1>

  <!-- Info Message (replaces deposit/withdraw forms) -->
  <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 sm:p-5" style="margin-bottom: 1.5rem;">
    <p class="text-blue-800 text-sm sm:text-base">
      All players start with <strong class="text-[#4CAF50]">$5,000</strong> in play money.
      Your bankroll changes based on your betting results. Good luck!
    </p>
  </div>

  <!-- Balance Card (KEEP - existing code from lines 9-31) -->
  <div class="bg-gray-100 border border-gray-300 rounded-lg p-5 sm:p-6" style="margin-bottom: 1.5rem;">
    <h2 class="text-lg sm:text-xl font-bold text-gray-800 mb-4">Account Balance</h2>
    <!-- ... existing balance display ... -->
  </div>

  <!-- REMOVED: Deposit Form Card (was lines 34-72) -->
  <!-- REMOVED: Withdraw Form Card (was lines 75-112) -->

  <!-- Transaction History (KEEP - existing code from lines 115-167) -->
  <div class="bg-gray-100 border border-gray-300 rounded-lg p-5 sm:p-6">
    <h2 class="text-lg sm:text-xl font-bold text-gray-800 mb-4">Recent Transactions</h2>

    <% if @recent_transactions.empty? %>
      <p class="text-gray-600 italic text-center py-4">
        No transactions yet. Place your first bet to get started!
      </p>
    <% else %>
      <!-- ... existing transaction table ... -->
    <% end %>
  </div>
</div>
```

## Test Updates Required

### Tests to Modify

| Test File | Change |
|-----------|--------|
| `test/models/user_test.rb` | Add test verifying bankroll created with $5,000 |
| `test/models/bankroll_test.rb` | Update any setup that assumes $0 initial balance |

### New Test Case

```ruby
# test/models/user_test.rb
test "new user receives initial bankroll of $5000" do
  user = User.create!(
    email: "newuser@example.com",
    password: "password123"
  )

  assert_not_nil user.bankroll
  assert_equal 5000.00, user.bankroll.available_balance
  assert_equal 0.00, user.bankroll.locked_balance
  assert_equal 'USD', user.bankroll.currency
end
```

## Dependencies & Risks

### Dependencies
- None - this is a self-contained change

### Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| User discovers backend routes | Low | Low | Routes still work but aren't advertised |
| Existing users stranded with $0 | Low | Medium | Document that existing users keep current balance |
| Test failures from balance assumption | Medium | Low | Update test setup |

## Success Metrics

- [ ] All new users can place bets immediately after registration
- [ ] Zero UI elements for deposit/withdraw visible to users
- [ ] Backend functionality verified working (via console/tests)
- [ ] App behavior matches FAQ documentation

## References

### Internal References
- FAQ page: `app/views/pages/faq.html.erb` - Documents $5,000 starting balance
- User model: `app/models/user.rb:37-39` - Current callback implementation
- Bankroll model: `app/models/bankroll.rb` - Balance management
- View: `app/views/bankrolls/show.html.erb` - Current UI with forms

### What's Preserved for Future Use
- Routes: `config/routes.rb:14-17` - deposit/withdraw endpoints
- Controller: `app/controllers/bankrolls_controller.rb:9-45` - deposit/withdraw actions
- Model: `app/models/bankroll.rb` - All methods including deposit/withdraw
- Constants: MIN_DEPOSIT, MIN_WITHDRAWAL, MAX_TRANSACTION

---

## Implementation Checklist

- [ ] Add `Bankroll::INITIAL_BALANCE = 5000.00` constant
- [ ] Update `User#create_default_bankroll` to use constant
- [ ] Remove deposit form from bankroll view
- [ ] Remove withdraw form from bankroll view
- [ ] Add info message about $5,000 starting balance
- [ ] Update empty transaction state message
- [ ] Add test for new user getting $5,000
- [ ] Manual test: new user registration
- [ ] Manual test: OAuth registration (Google/GitHub)
- [ ] Manual test: betting flow with new balance
- [ ] Verify backend routes still functional
