# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- **Betting/Offer System** - Complete 4-phase implementation:
  - **Phase 1 - Foundation**: `Bet` model with odds snapshots, validations, and settlement logic
    - Counter cache (`bets_count`) on betting lines to track bet volume
    - Clickable betting line UI with Stimulus controller (`bet_selector_controller.js`)
    - Helper methods for odds formatting and bet display
  - **Phase 2 - Bet Placement**: Modal-based bet slip for placing bets
    - `BetsController#create` with transaction handling and fund locking
    - Real-time payout calculation in bet slip modal (`bet_slip_controller.js`)
    - Custom validations: minimum bet ($5), sufficient balance, game not started
    - Integration with bankroll `lock_funds_for_bet` method
  - **Phase 3 - Bet Management**: Complete bet history and management interface
    - "My Bets" page showing pending and settled bets with status badges
    - Individual bet detail view with game info and payout breakdown
    - Bet cancellation functionality (only before game starts)
    - Navigation links added to header (desktop and mobile)
  - **Phase 4 - Settlement**: Automated bet settlement background job
    - `SettleBetsJob` runs every 10-15 minutes to settle completed games
    - Determines outcomes for moneyline, spread, and over/under bets
    - Handles wins, losses, and pushes with bankroll settlement methods
    - Comprehensive logging for settlement tracking
- **Betting System Routes**:
  - `POST /bets` - Place new bet
  - `GET /bets` - View all user bets
  - `GET /bets/:id` - View bet details
  - `POST /bets/:id/cancel` - Cancel pending bet
- **Design Documentation**: Complete betting system architecture in `docs/BETTING_SYSTEM_DESIGN.md`
- **Bankroll Management Page** (`app/views/bankrolls/show.html.erb`):
  - Display total balance, available balance, and locked balance
  - Deposit form with validation (min $10, max $10,000)
  - Withdraw form with validation (min $20, max available balance)
  - Recent transaction history table with color-coded transaction types
  - Mobile-responsive dark theme design
- **BankrollsController** with three actions:
  - `show` - Display bankroll management page
  - `deposit` - Process deposit requests
  - `withdraw` - Process withdrawal requests
- **Clickable bankroll display in navbar**:
  - Links to bankroll management page on both mobile and desktop views
  - Hover effect for better UX
  - Display format: `$X,XXX.XX`
- **Bankroll routes** (`config/routes.rb`):
  - `GET /bankroll` - Show bankroll page
  - `POST /bankroll/deposit` - Process deposits
  - `POST /bankroll/withdraw` - Process withdrawals
- **The Odds API Integration**: Complete service layer for fetching live odds data
  - `OddsApi::Client` - HTTParty-based API client with error handling and rate limit tracking
  - `OddsApi::TeamMatcher` - Fuzzy matching to map API teams to local database teams
  - `OddsApi::GameImporter` - Imports games and betting lines from API data
  - `OddsApi::SportsSync` - Orchestrates syncing multiple sports
- **Rake tasks for odds management** (`lib/tasks/odds.rake`):
  - `bin/rails odds:sync` - Sync all default sports (NBA, NFL, NCAAF)
  - `bin/rails odds:sync_sport[sport_key]` - Sync a specific sport
  - `bin/rails odds:list_sports` - List all available sports from the API
  - `bin/rails odds:usage` - Check API usage and rate limits
- **API tracking fields** via migration `AddApiFieldsToGamesAndTeams`:
  - Added `external_id`, `data_source`, `last_synced_at` to Games and Teams
  - Unique indexes on `external_id` for both models
- **Games controller and views** for displaying upcoming games with betting lines
- **Dependencies**: httparty, dotenv-rails, webmock, vcr
- **Comprehensive test coverage** for all service layer components

### Changed
- Updated Team and Game models with validations for `external_id` uniqueness
- Configured WebMock and VCR in test_helper.rb for API testing
- Set root route to `games#index` for sportsbook homepage
- **Navbar enhancements**:
  - Made bankroll amount clickable (links to `/bankroll`)
  - Added dark background to body (`bg-[#0f0f1e]`)
  - Bankroll display now shown in both mobile and desktop views

### Fixed
- **Fixed PaperTradingAdapter deposit/withdrawal logic** (`app/services/payment_adapters/paper_trading_adapter.rb`):
  - `charge` method now correctly credits account for deposits (was incorrectly debiting)
  - Removed balance check from deposits - unlimited paper trading funds
  - `withdraw` method now correctly debits account for withdrawals (was incorrectly crediting)
  - Added balance check to withdrawals to prevent overdrafts
  - Previously deposits failed with "Insufficient funds" error
- Fixed VS Code Ruby LSP workspace activation hanging by changing from `custom` to `rbenv` identifier in `.vscode/settings.json`
- Fixed test route helper - changed from `games_index_url` to `games_url` in controller tests
- Added `resources :games, only: [:index]` route to properly generate URL helpers
- Fixed TeamMatcher fuzzy matching causing incorrect team assignments (e.g., "Boston College Eagles" was incorrectly matched to "Georgia Southern Eagles"). Removed substring matching and now uses exact match only.
