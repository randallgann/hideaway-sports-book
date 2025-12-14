# frozen_string_literal: true

namespace :leaderboard do
  desc "Backfill user bet counter caches"
  task backfill_counters: :environment do
    puts "Backfilling user bet counter caches..."

    User.find_each do |user|
      User.reset_counters(user.id, :bets)
      user.update_columns(
        won_bets_count: user.bets.won.count,
        lost_bets_count: user.bets.lost.count,
        push_bets_count: user.bets.where(status: "push").count
      )
      print "."
    end

    puts "\nDone! Counter caches updated for #{User.count} users."
  end
end
