# feat: Implement Leaderboard Feature

## Overview

Add a leaderboard feature to the Hideaway Sportsbook that ranks all players based on their total returns. Since everyone starts with the same $5,000, the rankings reflect pure betting skill and strategy. This feature enables friendly competition and engagement between users.

**Source**: FAQ section describes: "The leaderboard ranks all players based on their total returns. Everyone starts with the same $5,000, so the rankings reflect pure betting skill and strategy. Compete against friends and other players to see who can grow their bankroll the most."

## Problem Statement / Motivation

Currently, users can place bets and track their own bankroll, but there's no way to see how they stack up against other players. The FAQ already promises a leaderboard feature, and users expect competitive elements in a sportsbook application. This feature will:

1. **Increase engagement**: Competition motivates users to return and place strategic bets
2. **Provide social proof**: Show that the platform has active users
3. **Enable learning**: Users can see what successful betting looks like (balance growth, win rates)
4. **Fulfill FAQ promise**: The FAQ explicitly mentions leaderboard competition

## Proposed Solution

Create a publicly accessible leaderboard page (`/leaderboard`) that displays:
- Player rankings by total balance (default)
- Key metrics: Balance, Profit/Loss, ROI%, Win Rate%, Total Bets
- Pagination (25 players per page)
- Current user highlighting
- Top 3 medals (🥇🥈🥉)
- Multiple sort options

### Technical Approach

Follow existing patterns from `HouseController` (public access, stats-focused) and `BetsController` (paginated lists with filtering).

## Technical Considerations

### Architecture Impacts
- **New Controller**: `LeaderboardController` with public access (no authentication required)
- **Model Enhancements**: Add scopes to `User` model for leaderboard queries
- **Helper Module**: `LeaderboardHelper` for formatting rankings and metrics
- **Route Addition**: `resource :leaderboard, only: [:show], controller: "leaderboard"` or `get "leaderboard", to: "leaderboard#index"`

### Performance Implications
- **Query Complexity**: Joins users → bankrolls, calculates derived metrics
- **Pagination Required**: Must use Pagy gem for efficient pagination
- **Caching Strategy**: Cache leaderboard data for 5 minutes, invalidate on bet settlement
- **Index Needed**: Add index on `bankrolls.available_balance` for sorting performance

### Database Changes
- **Optional Counter Caches**: Add `bets_count`, `won_bets_count`, `lost_bets_count` to users table for performance
- **Privacy Field**: Add `show_on_leaderboard` boolean to users table (default: true)

### Security Considerations
- **Privacy**: Display username or "User #ID" - never expose email addresses
- **House Account Exclusion**: Filter out house account from all queries
- **Parameter Validation**: Sanitize sort parameters to prevent SQL injection

## Acceptance Criteria

### Functional Requirements

- [ ] **AC1**: Leaderboard page accessible at `/leaderboard` without authentication
- [ ] **AC2**: Default sort by total balance (available_balance + locked_balance) descending
- [ ] **AC3**: Display columns: Rank, Player Name, Total Balance, Profit/Loss, ROI%, Win Rate%, Total Bets
- [ ] **AC4**: Pagination with 25 users per page using Pagy gem
- [ ] **AC5**: Current user's row highlighted when viewing leaderboard (if logged in)
- [ ] **AC6**: Top 3 positions display medals: 🥇🥈🥉
- [ ] **AC7**: House account excluded from leaderboard
- [ ] **AC8**: Alternate sorting by: Total Balance, Profit/Loss, ROI%, Win Rate%
- [ ] **AC9**: Show user's own position if not on current page: "Your Rank: #X"
- [ ] **AC10**: Navigation link added to navbar

### Non-Functional Requirements

- [ ] **NFR1**: Page loads in < 500ms with 1000+ users
- [ ] **NFR2**: Mobile responsive design (card layout on small screens)
- [ ] **NFR3**: Visual consistency with existing dark theme (`bg-[#0f0f1e]`, `bg-[#1a1a2e]`)
- [ ] **NFR4**: Green for positive values, red for negative values

### Quality Gates

- [ ] All tests passing
- [ ] No N+1 queries (verified with Bullet gem or logs)
- [ ] RuboCop clean

## Implementation Plan

### Phase 1: Database Setup

**Migration: Add Counter Caches and Privacy Field**

Create migration to add performance-optimized columns:

```ruby
# db/migrate/XXXXXX_add_leaderboard_fields_to_users.rb
class AddLeaderboardFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    # Counter caches for performance
    add_column :users, :bets_count, :integer, default: 0, null: false
    add_column :users, :won_bets_count, :integer, default: 0, null: false
    add_column :users, :lost_bets_count, :integer, default: 0, null: false
    add_column :users, :push_bets_count, :integer, default: 0, null: false

    # Privacy opt-out
    add_column :users, :show_on_leaderboard, :boolean, default: true, null: false

    # Index for leaderboard privacy filter
    add_index :users, :show_on_leaderboard
  end
end
```

**Migration: Add Index for Balance Sorting**

```ruby
# db/migrate/XXXXXX_add_leaderboard_index_to_bankrolls.rb
class AddLeaderboardIndexToBankrolls < ActiveRecord::Migration[8.1]
  def change
    add_index :bankrolls, [:available_balance, :locked_balance],
              name: 'index_bankrolls_on_balance_for_leaderboard'
  end
end
```

**Rake Task: Backfill Counter Caches**

```ruby
# lib/tasks/leaderboard.rake
namespace :leaderboard do
  desc "Backfill user bet counter caches"
  task backfill_counters: :environment do
    User.find_each do |user|
      User.reset_counters(user.id, :bets)
      user.update_columns(
        won_bets_count: user.bets.won.count,
        lost_bets_count: user.bets.lost.count,
        push_bets_count: user.bets.where(status: 'push').count
      )
    end
  end
end
```

### Phase 2: Model Layer

**User Model Enhancements**

```ruby
# app/models/user.rb (additions)
class User < ApplicationRecord
  # Existing associations...
  has_many :bets, dependent: :destroy

  # Leaderboard scopes
  scope :players, -> { where(house: false) }
  scope :on_leaderboard, -> { where(show_on_leaderboard: true) }
  scope :with_bankroll, -> { joins(:bankroll) }

  scope :leaderboard_ordered, -> {
    players
      .on_leaderboard
      .with_bankroll
      .select(
        'users.*',
        '(bankrolls.available_balance + bankrolls.locked_balance) AS total_balance'
      )
      .order('total_balance DESC, users.created_at ASC')
  }

  scope :by_profit, -> {
    players
      .on_leaderboard
      .with_bankroll
      .select(
        'users.*',
        '(bankrolls.available_balance + bankrolls.locked_balance) AS total_balance',
        "(bankrolls.available_balance + bankrolls.locked_balance - #{Bankroll::INITIAL_BALANCE}) AS profit"
      )
      .order('profit DESC, users.created_at ASC')
  }

  scope :by_roi, -> {
    players
      .on_leaderboard
      .with_bankroll
      .select(
        'users.*',
        '(bankrolls.available_balance + bankrolls.locked_balance) AS total_balance',
        "((bankrolls.available_balance + bankrolls.locked_balance - #{Bankroll::INITIAL_BALANCE}) / #{Bankroll::INITIAL_BALANCE}.0 * 100) AS roi"
      )
      .order('roi DESC, users.created_at ASC')
  }

  scope :by_win_rate, -> {
    players
      .on_leaderboard
      .where('bets_count > 0')
      .select(
        'users.*',
        '(won_bets_count::float / bets_count * 100) AS win_rate'
      )
      .order('win_rate DESC, bets_count DESC, users.created_at ASC')
  }

  # Instance methods for leaderboard display
  def display_name
    username.presence || "Player ##{id}"
  end

  def profit_loss
    return 0 unless bankroll
    bankroll.total_balance - Bankroll::INITIAL_BALANCE
  end

  def roi_percentage
    return 0 if Bankroll::INITIAL_BALANCE.zero?
    (profit_loss / Bankroll::INITIAL_BALANCE * 100).round(2)
  end

  def win_rate_percentage
    return nil if bets_count.zero?
    (won_bets_count.to_f / bets_count * 100).round(1)
  end

  def leaderboard_rank
    User.players
        .on_leaderboard
        .with_bankroll
        .where('(bankrolls.available_balance + bankrolls.locked_balance) > ?', bankroll.total_balance)
        .count + 1
  end
end
```

**Update Bet Model for Counter Cache**

```ruby
# app/models/bet.rb (modifications)
class Bet < ApplicationRecord
  belongs_to :user, counter_cache: true

  # After status changes, update win/loss/push counters
  after_commit :update_user_result_counters, if: :saved_change_to_status?

  private

  def update_user_result_counters
    return unless user

    user.update_columns(
      won_bets_count: user.bets.won.count,
      lost_bets_count: user.bets.lost.count,
      push_bets_count: user.bets.where(status: 'push').count
    )
  end
end
```

### Phase 3: Controller Layer

**Leaderboard Controller**

```ruby
# app/controllers/leaderboard_controller.rb
class LeaderboardController < ApplicationController
  include Pagy::Backend

  skip_before_action :authenticate_user!

  VALID_SORTS = %w[balance profit roi win_rate].freeze
  PER_PAGE = 25

  def show
    @sort = VALID_SORTS.include?(params[:sort]) ? params[:sort] : 'balance'

    users_query = leaderboard_query_for(@sort)
    @pagy, @users = pagy(users_query, items: PER_PAGE)

    @current_user_rank = current_user&.leaderboard_rank if user_signed_in?
    @total_players = User.players.on_leaderboard.count
  end

  private

  def leaderboard_query_for(sort)
    case sort
    when 'profit'
      User.by_profit
    when 'roi'
      User.by_roi
    when 'win_rate'
      User.by_win_rate
    else
      User.leaderboard_ordered
    end.includes(:bankroll)
  end
end
```

### Phase 4: View Layer

**Leaderboard View**

```erb
<%# app/views/leaderboard/show.html.erb %>
<div class="w-full">
  <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between mb-6">
    <h1 class="text-2xl sm:text-3xl font-bold text-white mb-4 sm:mb-0">Leaderboard</h1>
    <div class="text-gray-400 text-sm">
      <%= @total_players %> <%= 'player'.pluralize(@total_players) %> competing
    </div>
  </div>

  <%# Current user position indicator (if not on current page) %>
  <% if user_signed_in? && @current_user_rank && !@users.map(&:id).include?(current_user.id) %>
    <div class="bg-[#1a1a2e] border border-[#4CAF50] rounded-lg p-4 mb-6">
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-4">
          <span class="text-[#4CAF50] font-bold text-xl">#<%= @current_user_rank %></span>
          <span class="text-white font-medium">Your Position</span>
        </div>
        <div class="text-right">
          <div class="text-white font-bold"><%= number_to_currency(current_user.bankroll.total_balance) %></div>
          <div class="text-sm <%= current_user.profit_loss >= 0 ? 'text-green-400' : 'text-red-400' %>">
            <%= current_user.profit_loss >= 0 ? '+' : '' %><%= number_to_currency(current_user.profit_loss) %>
          </div>
        </div>
      </div>
    </div>
  <% end %>

  <%# Sort options %>
  <div class="flex gap-2 mb-6 flex-wrap">
    <%= link_to "Balance", leaderboard_path(sort: 'balance'),
        class: "px-4 py-2 rounded-lg text-sm font-medium transition-colors #{@sort == 'balance' ? 'bg-[#4CAF50] text-white' : 'bg-[#1a1a2e] text-gray-300 hover:bg-[#252540]'}" %>
    <%= link_to "Profit", leaderboard_path(sort: 'profit'),
        class: "px-4 py-2 rounded-lg text-sm font-medium transition-colors #{@sort == 'profit' ? 'bg-[#4CAF50] text-white' : 'bg-[#1a1a2e] text-gray-300 hover:bg-[#252540]'}" %>
    <%= link_to "ROI %", leaderboard_path(sort: 'roi'),
        class: "px-4 py-2 rounded-lg text-sm font-medium transition-colors #{@sort == 'roi' ? 'bg-[#4CAF50] text-white' : 'bg-[#1a1a2e] text-gray-300 hover:bg-[#252540]'}" %>
    <%= link_to "Win Rate", leaderboard_path(sort: 'win_rate'),
        class: "px-4 py-2 rounded-lg text-sm font-medium transition-colors #{@sort == 'win_rate' ? 'bg-[#4CAF50] text-white' : 'bg-[#1a1a2e] text-gray-300 hover:bg-[#252540]'}" %>
  </div>

  <%# Desktop table %>
  <div class="hidden md:block bg-[#1a1a2e] rounded-lg overflow-hidden">
    <table class="w-full">
      <thead class="bg-[#252540]">
        <tr>
          <th class="px-4 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">Rank</th>
          <th class="px-4 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">Player</th>
          <th class="px-4 py-3 text-right text-xs font-medium text-gray-400 uppercase tracking-wider">Balance</th>
          <th class="px-4 py-3 text-right text-xs font-medium text-gray-400 uppercase tracking-wider">Profit/Loss</th>
          <th class="px-4 py-3 text-right text-xs font-medium text-gray-400 uppercase tracking-wider">ROI</th>
          <th class="px-4 py-3 text-right text-xs font-medium text-gray-400 uppercase tracking-wider">Win Rate</th>
          <th class="px-4 py-3 text-right text-xs font-medium text-gray-400 uppercase tracking-wider">Bets</th>
        </tr>
      </thead>
      <tbody class="divide-y divide-gray-700">
        <% @users.each_with_index do |user, index| %>
          <% rank = @pagy.offset + index + 1 %>
          <% is_current_user = user_signed_in? && user.id == current_user.id %>
          <tr class="<%= is_current_user ? 'bg-[#4CAF50]/10 border-l-4 border-[#4CAF50]' : 'hover:bg-[#252540]' %>">
            <td class="px-4 py-4 whitespace-nowrap">
              <span class="<%= rank <= 3 ? 'text-2xl' : 'text-gray-300 font-medium' %>">
                <%= rank_badge(rank) %>
              </span>
            </td>
            <td class="px-4 py-4 whitespace-nowrap">
              <span class="text-white font-medium"><%= user.display_name %></span>
              <% if is_current_user %>
                <span class="ml-2 text-xs text-[#4CAF50]">(You)</span>
              <% end %>
            </td>
            <td class="px-4 py-4 whitespace-nowrap text-right">
              <span class="text-white font-bold"><%= number_to_currency(user.total_balance || user.bankroll.total_balance) %></span>
            </td>
            <td class="px-4 py-4 whitespace-nowrap text-right">
              <% profit = user.respond_to?(:profit) ? user.profit : user.profit_loss %>
              <span class="<%= profit >= 0 ? 'text-green-400' : 'text-red-400' %>">
                <%= profit >= 0 ? '+' : '' %><%= number_to_currency(profit) %>
              </span>
            </td>
            <td class="px-4 py-4 whitespace-nowrap text-right">
              <% roi = user.respond_to?(:roi) ? user.roi : user.roi_percentage %>
              <span class="<%= roi >= 0 ? 'text-green-400' : 'text-red-400' %>">
                <%= roi >= 0 ? '+' : '' %><%= number_to_percentage(roi, precision: 1) %>
              </span>
            </td>
            <td class="px-4 py-4 whitespace-nowrap text-right">
              <% win_rate = user.respond_to?(:win_rate) ? user.win_rate : user.win_rate_percentage %>
              <% if win_rate.nil? %>
                <span class="text-gray-500">--</span>
              <% else %>
                <span class="text-gray-300"><%= number_to_percentage(win_rate, precision: 1) %></span>
              <% end %>
            </td>
            <td class="px-4 py-4 whitespace-nowrap text-right">
              <span class="text-gray-300"><%= user.bets_count %></span>
            </td>
          </tr>
        <% end %>
      </tbody>
    </table>
  </div>

  <%# Mobile cards %>
  <div class="md:hidden space-y-4">
    <% @users.each_with_index do |user, index| %>
      <% rank = @pagy.offset + index + 1 %>
      <% is_current_user = user_signed_in? && user.id == current_user.id %>
      <div class="bg-[#1a1a2e] rounded-lg p-4 <%= is_current_user ? 'border-2 border-[#4CAF50]' : '' %>">
        <div class="flex items-center justify-between mb-3">
          <div class="flex items-center gap-3">
            <span class="<%= rank <= 3 ? 'text-2xl' : 'text-xl text-gray-300 font-bold' %>">
              <%= rank_badge(rank) %>
            </span>
            <div>
              <span class="text-white font-medium"><%= user.display_name %></span>
              <% if is_current_user %>
                <span class="ml-2 text-xs text-[#4CAF50]">(You)</span>
              <% end %>
            </div>
          </div>
          <div class="text-right">
            <div class="text-white font-bold"><%= number_to_currency(user.total_balance || user.bankroll.total_balance) %></div>
          </div>
        </div>
        <div class="grid grid-cols-3 gap-2 text-sm">
          <div>
            <div class="text-gray-500 text-xs">Profit</div>
            <% profit = user.respond_to?(:profit) ? user.profit : user.profit_loss %>
            <div class="<%= profit >= 0 ? 'text-green-400' : 'text-red-400' %>">
              <%= profit >= 0 ? '+' : '' %><%= number_to_currency(profit) %>
            </div>
          </div>
          <div>
            <div class="text-gray-500 text-xs">ROI</div>
            <% roi = user.respond_to?(:roi) ? user.roi : user.roi_percentage %>
            <div class="<%= roi >= 0 ? 'text-green-400' : 'text-red-400' %>">
              <%= roi >= 0 ? '+' : '' %><%= number_to_percentage(roi, precision: 1) %>
            </div>
          </div>
          <div>
            <div class="text-gray-500 text-xs">Win Rate</div>
            <% win_rate = user.respond_to?(:win_rate) ? user.win_rate : user.win_rate_percentage %>
            <div class="text-gray-300">
              <%= win_rate.nil? ? '--' : number_to_percentage(win_rate, precision: 1) %>
            </div>
          </div>
        </div>
      </div>
    <% end %>
  </div>

  <%# Pagination %>
  <% if @pagy.pages > 1 %>
    <div class="mt-6 flex justify-center">
      <%== pagy_nav(@pagy) %>
    </div>
  <% end %>
</div>
```

**Leaderboard Helper**

```ruby
# app/helpers/leaderboard_helper.rb
module LeaderboardHelper
  def rank_badge(position)
    case position
    when 1 then "🥇"
    when 2 then "🥈"
    when 3 then "🥉"
    else "##{position}"
    end
  end
end
```

### Phase 5: Routes & Navigation

**Add Route**

```ruby
# config/routes.rb (addition)
resource :leaderboard, only: [:show], controller: "leaderboard"
```

**Add Navbar Link**

```erb
<%# app/views/layouts/application.html.erb (in navbar) %>
<%= link_to "Leaderboard", leaderboard_path,
    class: "text-gray-300 hover:text-white transition-colors duration-200" %>
```

### Phase 6: Pagy Setup

**Add Pagy Gem**

```ruby
# Gemfile
gem 'pagy', '~> 9.4'
```

**Configure Pagy**

```ruby
# config/initializers/pagy.rb
require 'pagy/extras/overflow'

Pagy::DEFAULT[:limit] = 25
Pagy::DEFAULT[:overflow] = :last_page

# For Tailwind styling
Pagy::DEFAULT[:nav_extra] = 'rounded-lg'
```

**Include Pagy in Application Controller**

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include Pagy::Backend
  # ... existing code
end
```

**Include Pagy Helper**

```ruby
# app/helpers/application_helper.rb
module ApplicationHelper
  include Pagy::Frontend
  # ... existing code
end
```

### Phase 7: Testing

**Controller Test**

```ruby
# test/controllers/leaderboard_controller_test.rb
require "test_helper"

class LeaderboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user1 = users(:one)
    @user2 = users(:two)
  end

  test "should get leaderboard without authentication" do
    get leaderboard_path
    assert_response :success
  end

  test "should display users ordered by balance" do
    get leaderboard_path
    assert_response :success
    assert_select "table tbody tr"
  end

  test "should filter by sort parameter" do
    get leaderboard_path(sort: 'profit')
    assert_response :success
  end

  test "should ignore invalid sort parameter" do
    get leaderboard_path(sort: 'invalid')
    assert_response :success
  end

  test "should highlight current user when signed in" do
    sign_in @user1
    get leaderboard_path
    assert_response :success
    assert_select ".border-\\[\\#4CAF50\\]"
  end

  test "should exclude house account from leaderboard" do
    house = User.house_user
    get leaderboard_path
    assert_not response.body.include?(house.email)
  end
end
```

**Model Test for Scopes**

```ruby
# test/models/user_test.rb (additions)
class UserTest < ActiveSupport::TestCase
  test "leaderboard_ordered excludes house account" do
    house = User.house_user
    leaderboard = User.leaderboard_ordered
    assert_not leaderboard.include?(house)
  end

  test "leaderboard_ordered orders by total balance descending" do
    leaderboard = User.leaderboard_ordered.to_a
    balances = leaderboard.map { |u| u.total_balance || u.bankroll.total_balance }
    assert_equal balances, balances.sort.reverse
  end

  test "display_name returns username when present" do
    user = User.new(username: "testuser")
    assert_equal "testuser", user.display_name
  end

  test "display_name returns Player #ID when username blank" do
    user = User.create!(email: "test@example.com", password: "password123")
    assert_equal "Player ##{user.id}", user.display_name
  end
end
```

## File Structure Summary

```
app/
├── controllers/
│   └── leaderboard_controller.rb         # NEW
├── helpers/
│   └── leaderboard_helper.rb             # NEW
├── models/
│   ├── user.rb                           # MODIFY (add scopes, methods)
│   └── bet.rb                            # MODIFY (add counter cache callback)
└── views/
    ├── layouts/
    │   └── application.html.erb          # MODIFY (add navbar link)
    └── leaderboard/
        └── show.html.erb                 # NEW

config/
├── initializers/
│   └── pagy.rb                           # NEW
└── routes.rb                             # MODIFY (add route)

db/
└── migrate/
    ├── XXXXXX_add_leaderboard_fields_to_users.rb    # NEW
    └── XXXXXX_add_leaderboard_index_to_bankrolls.rb # NEW

lib/
└── tasks/
    └── leaderboard.rake                  # NEW (backfill task)

test/
├── controllers/
│   └── leaderboard_controller_test.rb    # NEW
└── models/
    └── user_test.rb                      # MODIFY (add scope tests)

Gemfile                                   # MODIFY (add pagy gem)
```

## ERD Changes

```mermaid
erDiagram
    User ||--|| Bankroll : has_one
    User ||--o{ Bet : has_many

    User {
        bigint id PK
        string email UK
        string username UK
        string name
        boolean house
        boolean show_on_leaderboard "NEW - default true"
        integer bets_count "NEW - counter cache"
        integer won_bets_count "NEW - counter cache"
        integer lost_bets_count "NEW - counter cache"
        integer push_bets_count "NEW - counter cache"
        datetime created_at
        datetime updated_at
    }

    Bankroll {
        bigint id PK
        bigint user_id FK UK
        decimal available_balance
        decimal locked_balance
        string currency
    }

    Bet {
        bigint id PK
        bigint user_id FK
        string status
        decimal amount
        decimal actual_payout
        datetime created_at
    }
```

## Dependencies

- **Pagy gem** (~> 9.4) - Must be added to Gemfile
- **Counter cache columns** - Requires migration before deployment

## Success Metrics

1. **Engagement**: Track visits to `/leaderboard` page
2. **Retention**: Compare bet frequency for users who view leaderboard vs those who don't
3. **Performance**: Page load time < 500ms

## Risks & Mitigations

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Performance degradation with many users | Medium | High | Add database indexes, implement caching |
| Privacy concerns | Low | Medium | Display username only, add opt-out option |
| Counter cache synchronization | Low | Medium | Add rake task for manual reconciliation |

## Future Enhancements

- Time-based leaderboards (weekly, monthly, all-time)
- Sport-specific leaderboards
- Achievement badges
- Friends/following system for private leaderboards
- Historical rank tracking

## References

### Internal References
- `app/models/user.rb` - User model with house account logic
- `app/models/bankroll.rb:11` - INITIAL_BALANCE constant (5000.00)
- `app/controllers/house_controller.rb` - Pattern for public stats page
- `app/views/house/show.html.erb` - UI pattern for stats display
- `app/helpers/betting_helper.rb` - Formatting helpers pattern

### External References
- [Pagy Documentation](https://github.com/ddnexus/pagy)
- [Rails Active Record Querying Guide](https://guides.rubyonrails.org/active_record_querying.html)
- [PostgreSQL Window Functions](https://www.postgresql.org/docs/current/tutorial-window.html)

---

**Document Created**: 2025-12-14
