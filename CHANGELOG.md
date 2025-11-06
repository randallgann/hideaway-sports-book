# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
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

### Fixed
- Fixed VS Code Ruby LSP workspace activation hanging by changing from `custom` to `rbenv` identifier in `.vscode/settings.json`
- Fixed test route helper - changed from `games_index_url` to `games_url` in controller tests
- Added `resources :games, only: [:index]` route to properly generate URL helpers
- Fixed TeamMatcher fuzzy matching causing incorrect team assignments (e.g., "Boston College Eagles" was incorrectly matched to "Georgia Southern Eagles"). Removed substring matching and now uses exact match only.
