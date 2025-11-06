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

ActiveRecord::Schema[8.1].define(version: 2025_11_06_014926) do
ActiveRecord::Schema[8.1].define(version: 2025_11_06_005619) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "bankroll_transactions", force: :cascade do |t|
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.decimal "balance_after", precision: 10, scale: 2, null: false
    t.decimal "balance_before", precision: 10, scale: 2, null: false
    t.bigint "bankroll_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.text "metadata"
    t.string "payment_transaction_id"
    t.string "reference_id"
    t.string "transaction_type", null: false
    t.datetime "updated_at", null: false
    t.index ["bankroll_id"], name: "index_bankroll_transactions_on_bankroll_id"
    t.index ["created_at"], name: "index_bankroll_transactions_on_created_at"
    t.index ["payment_transaction_id"], name: "index_bankroll_transactions_on_payment_transaction_id"
    t.index ["reference_id"], name: "index_bankroll_transactions_on_reference_id"
    t.index ["transaction_type"], name: "index_bankroll_transactions_on_transaction_type"
  end

  create_table "bankrolls", force: :cascade do |t|
    t.decimal "available_balance", precision: 10, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "USD", null: false
    t.decimal "locked_balance", precision: 10, scale: 2, default: "0.0", null: false
    t.string "payment_processor", default: "paper_trading", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_bankrolls_on_user_id", unique: true
  end

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

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "name"
    t.string "provider"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "uid"
    t.datetime "updated_at", null: false
    t.string "username"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.string "email"
    t.datetime "updated_at", null: false
    t.string "username"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "bankroll_transactions", "bankrolls"
  add_foreign_key "bankrolls", "users"
  add_foreign_key "betting_lines", "games"
  add_foreign_key "games", "teams", column: "away_team_id"
  add_foreign_key "games", "teams", column: "home_team_id"
  add_foreign_key "paper_trading_transactions", "paper_trading_accounts"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
end
