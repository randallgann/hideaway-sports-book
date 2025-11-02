namespace :odds do
  desc "Sync odds for all default sports (NBA, NFL, NCAAF)"
  task sync: :environment do
    puts "Starting odds sync for all sports..."
    puts "=" * 60

    syncer = OddsApi::SportsSync.new
    result = syncer.sync_all

    puts "\n" + "=" * 60
    puts "Sync Complete!"
    puts "=" * 60
    puts "Sports synced: #{result[:sports_synced]}"
    puts "Games created: #{result[:total_games_created]}"
    puts "Games updated: #{result[:total_games_updated]}"
    puts "Synced at: #{result[:synced_at]}"

    if result[:errors].any?
      puts "\nErrors encountered:"
      result[:errors].each do |error|
        puts "  - #{error[:sport]}: #{error[:error]}"
      end
    end

    puts "=" * 60
  end

  desc "Sync odds for a specific sport (e.g., rake odds:sync_sport[basketball_nba])"
  task :sync_sport, [:sport_key] => :environment do |t, args|
    sport_key = args[:sport_key]

    if sport_key.nil?
      puts "Error: Please provide a sport key"
      puts "Usage: rake odds:sync_sport[basketball_nba]"
      puts "\nAvailable sports:"
      puts "  - basketball_nba"
      puts "  - americanfootball_nfl"
      puts "  - americanfootball_ncaaf"
      exit 1
    end

    puts "Starting odds sync for #{sport_key}..."
    puts "=" * 60

    syncer = OddsApi::SportsSync.new
    result = syncer.sync_sport(sport_key)

    puts "\n" + "=" * 60
    if result[:success]
      puts "Sync Complete!"
      puts "=" * 60
      puts "Sport: #{result[:sport]}"
      puts "Games created: #{result[:games_created]}"
      puts "Games updated: #{result[:games_updated]}"
      puts "Synced at: #{result[:synced_at]}"
    else
      puts "Sync Failed!"
      puts "=" * 60
      puts "Sport: #{result[:sport]}"
      puts "Error: #{result[:error]}"
      puts "Synced at: #{result[:synced_at]}"
    end
    puts "=" * 60
  end

  desc "List available sports from The Odds API"
  task list_sports: :environment do
    puts "Fetching available sports from The Odds API..."
    puts "=" * 60

    begin
      client = OddsApi::Client.new
      sports = client.fetch_sports

      puts "\nAvailable Sports:"
      puts "=" * 60

      sports.each do |sport|
        puts "\nKey: #{sport['key']}"
        puts "Title: #{sport['title']}"
        puts "Group: #{sport['group']}"
        puts "Active: #{sport['active']}"
        puts "-" * 40
      end

      puts "\nTotal sports: #{sports.count}"
      puts "Requests remaining: #{client.requests_remaining}"
      puts "=" * 60
    rescue OddsApi::Client::MissingApiKeyError => e
      puts "Error: #{e.message}"
      puts "Please set ODDS_API_KEY in your .env file"
    rescue => e
      puts "Error: #{e.message}"
    end
  end

  desc "Show API usage statistics"
  task usage: :environment do
    puts "Checking API usage..."
    puts "=" * 60

    begin
      client = OddsApi::Client.new
      # Make a lightweight request to get rate limit info
      client.fetch_sports

      puts "\nAPI Usage Statistics:"
      puts "=" * 60
      puts "Requests used: #{client.requests_used}"
      puts "Requests remaining: #{client.requests_remaining}"
      puts "=" * 60
    rescue OddsApi::Client::MissingApiKeyError => e
      puts "Error: #{e.message}"
      puts "Please set ODDS_API_KEY in your .env file"
    rescue => e
      puts "Error: #{e.message}"
    end
  end
end
