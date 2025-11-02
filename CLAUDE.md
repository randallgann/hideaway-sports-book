# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **casual learning project** for understanding Ruby on Rails and sports betting mechanics. The focus is on rapid implementation and learning fundamentals rather than production-ready code. The project intentionally excludes user authentication, payment processing, advanced error handling, and deployment configurations.

**Ruby Version**: 3.3.6
**Rails Version**: 8.1.0
**Database**: PostgreSQL 16 (running in Docker)

## Initial Setup

### Environment Variables
Copy the example environment file and configure your credentials:
```bash
cp .env.example .env
```

Then edit `.env` and set:
- `ODDS_API_KEY`: Your API key from https://the-odds-api.com/
- `POSTGRES_USER`: Database username (e.g., `postgres`)
- `POSTGRES_PASSWORD`: Database password (choose a secure password)

## Docker Setup

This project uses Docker Compose to run PostgreSQL. The database runs in a container for easy setup and teardown.

### Prerequisites
- Docker and Docker Compose installed on your machine

### Starting the Database
```bash
# Start PostgreSQL in detached mode
docker-compose up -d

# Check if the container is running
docker ps

# View logs
docker-compose logs postgres
```

### Stopping the Database
```bash
# Stop the database container
docker-compose down

# Stop and remove volumes (WARNING: deletes all data)
docker-compose down -v
```

### Database Configuration
- **Development DB**: `hideaway_sports_book_db`
- **Test DB**: `hideaway_sports_book_test_db`
- **Port**: 5433 (mapped from container's 5432 to avoid conflicts with other PostgreSQL instances)
- **Credentials**: Set in `.env` file (see `.env.example`)

## Development Environment

**VS Code Configuration**: Uses Shopify Ruby LSP extension with rbenv version manager. Configuration in `.vscode/settings.json` uses `rubyLsp.rubyVersionManager.identifier: "rbenv"` to auto-detect Ruby version from `.ruby-version` file. Tests can be run via VS Code UI or command line.

## Git Workflow

**Main Branch**: `main` is the production branch. All feature work should be branched from main and merged back via pull requests.

**Branch Naming**:
- Feature branches: `feature/description` (e.g., `feature/add-user-bets`)
- Hotfix branches: `hotfix/description` (e.g., `hotfix/fix-odds-calculation`)
- Bug fix branches: `bugfix/description` (e.g., `bugfix/broken-game-display`)

**Workflow**:
```bash
# Start new feature from main
git checkout main
git pull origin main
git checkout -b feature/my-feature

# Work on feature, commit changes
git add .
git commit -m "Description of changes"

# Push and create PR
git push -u origin feature/my-feature
# Then create pull request on GitHub to merge into main
```

## Common Commands

### Development Server
```bash
bin/rails server
# Server runs on http://localhost:3000
```

### Database Management
```bash
# Create database
bin/rails db:create

# Run migrations
bin/rails db:migrate

# Seed database with sample data (NFL/NBA teams and games)
bin/rails db:seed

# Reset database (drop, create, migrate, seed)
bin/rails db:reset

# Rollback last migration
bin/rails db:rollback
```

### Testing
```bash
# Run all tests
bin/rails test

# Run specific test file
bin/rails test test/models/team_test.rb

# Run specific test by line number
bin/rails test test/models/team_test.rb:10

# Run system tests
bin/rails test:system
```

### Code Quality
```bash
# Run RuboCop linter
bundle exec rubocop

# Auto-fix RuboCop issues
bundle exec rubocop -a

# Run security audit
bundle exec bundler-audit check

# Run Brakeman security scanner
bundle exec brakeman
```

### Rails Console
```bash
bin/rails console
# or
bin/rails c
```

### Rails Generators
```bash
# Generate model
bin/rails generate model ModelName field:type

# Generate controller
bin/rails generate controller ControllerName action1 action2

# Generate migration
bin/rails generate migration MigrationName
```

### Odds API Integration
```bash
# Sync odds from The Odds API for all sports (NBA, NFL, NCAAF)
bin/rails odds:sync

# Sync a specific sport
bin/rails odds:sync_sport[basketball_nba]

# List all available sports
bin/rails odds:list_sports
```
**API Key**: Set `ODDS_API_KEY` in `.env` file. Service layer in `app/services/odds_api/` handles fetching, team matching, and importing games with live betting lines.

## Database Schema

The application has three core models representing a sportsbook system:

### Teams
- Fields: `name`, `city`, `abbreviation`, `sport`, `external_id`, `data_source`
- Relationships: `has_many :home_games`, `has_many :away_games`
- API tracking: `external_id` (unique), `data_source` (defaults to "manual")

### Games
- Fields: `game_time`, `sport`, `status`, `home_score`, `away_score`, `external_id`, `data_source`, `last_synced_at`
- Relationships:
  - `belongs_to :home_team` (class: Team)
  - `belongs_to :away_team` (class: Team)
  - `has_many :betting_lines` (dependent: destroy)
- Key concept: Games reference teams twice (home/away), using foreign keys `home_team_id` and `away_team_id`
- API tracking: `external_id` (unique), `data_source` (defaults to "manual"), `last_synced_at`

### BettingLines
- Fields: `line_type`, `home_odds`, `away_odds`, `spread`, `total`, `over_odds`, `under_odds`
- Relationships: `belongs_to :game`
- Line types: "moneyline", "spread", "over_under"
- Odds format: American odds (e.g., -150, +130)
- Each game can have multiple betting lines (one per type)

## Sports Betting Concepts

### Line Types
- **Moneyline**: Bet on which team wins outright (home_odds/away_odds)
- **Spread**: Bet on margin of victory (spread field, typically negative for favorite)
- **Over/Under**: Bet on total combined score (total field, with over_odds/under_odds)

### American Odds Format
- Negative odds (e.g., -150): Amount to bet to win $100 (favorite)
- Positive odds (e.g., +130): Amount won on $100 bet (underdog)

## Architecture Notes

### Model Associations
The Game model uses self-referential team associations with custom foreign keys:
```ruby
belongs_to :home_team, class_name: 'Team', foreign_key: 'home_team_id'
belongs_to :away_team, class_name: 'Team', foreign_key: 'away_team_id'
```

This pattern allows a single team to participate in multiple games as either home or away.

### Seed Data
The seed file (db/seeds.rb) provides sample NFL and NBA teams with realistic betting lines. It demonstrates:
- Multiple sports (NFL, NBA)
- All three betting line types
- Realistic odds and spreads
- Games scheduled using relative dates (1-3 days from now)

## Development Philosophy

Per PROJECT_OVERVIEW.md:
- **Quick iteration over perfection**: Get features working first
- **Learning focus**: Understanding Ruby patterns and Rails conventions is priority
- **Local development only**: No deployment or production concerns
- **Generic UI is acceptable**: No need for fancy styling
- **Simplified scope**: No auth, logging systems, or payment processing
