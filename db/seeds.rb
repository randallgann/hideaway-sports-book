# Clear existing data
BettingLine.destroy_all
Game.destroy_all
Team.destroy_all

# Create NFL teams
chiefs = Team.create!(name: "Chiefs", city: "Kansas City", abbreviation: "KC", sport: "nfl")
bills = Team.create!(name: "Bills", city: "Buffalo", abbreviation: "BUF", sport: "nfl")
eagles = Team.create!(name: "Eagles", city: "Philadelphia", abbreviation: "PHI", sport: "nfl")
niners = Team.create!(name: "49ers", city: "San Francisco", abbreviation: "SF", sport: "nfl")

# Create NBA teams
lakers = Team.create!(name: "Lakers", city: "Los Angeles", abbreviation: "LAL", sport: "nba")
celtics = Team.create!(name: "Celtics", city: "Boston", abbreviation: "BOS", sport: "nba")
warriors = Team.create!(name: "Warriors", city: "Golden State", abbreviation: "GSW", sport: "nba")
heat = Team.create!(name: "Heat", city: "Miami", abbreviation: "MIA", sport: "nba")

puts "Created #{Team.count} teams"

# Create upcoming games
game1 = Game.create!(
  home_team: chiefs,
  away_team: bills,
  game_time: 2.days.from_now,
  sport: "nfl",
  status: "scheduled"
)

game2 = Game.create!(
  home_team: eagles,
  away_team: niners,
  game_time: 3.days.from_now,
  sport: "nfl",
  status: "scheduled"
)

game3 = Game.create!(
  home_team: lakers,
  away_team: celtics,
  game_time: 1.day.from_now,
  sport: "nba",
  status: "scheduled"
)

game4 = Game.create!(
  home_team: warriors,
  away_team: heat,
  game_time: 2.days.from_now,
  sport: "nba",
  status: "scheduled"
)

puts "Created #{Game.count} games"

# Create betting lines for each game

# Game 1: Chiefs vs Bills
BettingLine.create!(
  game: game1,
  line_type: "moneyline",
  home_odds: -150.00,
  away_odds: 130.00
)

BettingLine.create!(
  game: game1,
  line_type: "spread",
  home_odds: -110.00,
  away_odds: -110.00,
  spread: -3.5
)

BettingLine.create!(
  game: game1,
  line_type: "over_under",
  total: 47.5,
  over_odds: -110.00,
  under_odds: -110.00
)

# Game 2: Eagles vs 49ers
BettingLine.create!(
  game: game2,
  line_type: "moneyline",
  home_odds: -120.00,
  away_odds: 100.00
)

BettingLine.create!(
  game: game2,
  line_type: "spread",
  home_odds: -110.00,
  away_odds: -110.00,
  spread: -2.5
)

BettingLine.create!(
  game: game2,
  line_type: "over_under",
  total: 44.5,
  over_odds: -115.00,
  under_odds: -105.00
)

# Game 3: Lakers vs Celtics
BettingLine.create!(
  game: game3,
  line_type: "moneyline",
  home_odds: 110.00,
  away_odds: -130.00
)

BettingLine.create!(
  game: game3,
  line_type: "spread",
  home_odds: -110.00,
  away_odds: -110.00,
  spread: 3.0
)

BettingLine.create!(
  game: game3,
  line_type: "over_under",
  total: 220.5,
  over_odds: -110.00,
  under_odds: -110.00
)

# Game 4: Warriors vs Heat
BettingLine.create!(
  game: game4,
  line_type: "moneyline",
  home_odds: -180.00,
  away_odds: 155.00
)

BettingLine.create!(
  game: game4,
  line_type: "spread",
  home_odds: -110.00,
  away_odds: -110.00,
  spread: -5.5
)

BettingLine.create!(
  game: game4,
  line_type: "over_under",
  total: 215.0,
  over_odds: -110.00,
  under_odds: -110.00
)

puts "Created #{BettingLine.count} betting lines"
puts "Seed data loaded successfully!"
