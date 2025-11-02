# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2025_11_01_161715) do
  create_table "betting_lines", force: :cascade do |t|
    t.decimal "away_odds", precision: 8, scale: 2
    t.datetime "created_at", null: false
    t.integer "game_id", null: false
    t.decimal "home_odds", precision: 8, scale: 2
    t.string "line_type"
    t.decimal "over_odds", precision: 8, scale: 2
    t.decimal "spread", precision: 8, scale: 2
    t.decimal "total", precision: 8, scale: 2
    t.decimal "under_odds", precision: 8, scale: 2
    t.datetime "updated_at", null: false
    t.index ["game_id"], name: "index_betting_lines_on_game_id"
  end

  create_table "games", force: :cascade do |t|
    t.integer "away_score"
    t.integer "away_team_id", null: false
    t.datetime "created_at", null: false
    t.string "data_source", default: "manual"
    t.string "external_id"
    t.datetime "game_time"
    t.integer "home_score"
    t.integer "home_team_id", null: false
    t.datetime "last_synced_at"
    t.string "sport"
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["away_team_id"], name: "index_games_on_away_team_id"
    t.index ["external_id"], name: "index_games_on_external_id", unique: true
    t.index ["home_team_id"], name: "index_games_on_home_team_id"
  end

  create_table "teams", force: :cascade do |t|
    t.string "abbreviation"
    t.string "city"
    t.datetime "created_at", null: false
    t.string "data_source", default: "manual"
    t.string "external_id"
    t.string "name"
    t.string "sport"
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_teams_on_external_id", unique: true
  end

  add_foreign_key "betting_lines", "games"
  add_foreign_key "games", "teams", column: "away_team_id"
  add_foreign_key "games", "teams", column: "home_team_id"
end
