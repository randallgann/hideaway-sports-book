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

ActiveRecord::Schema[8.1].define(version: 2025_11_08_215103) do
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

  create_table "bets", force: :cascade do |t|
    t.decimal "actual_payout", precision: 10, scale: 2
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.bigint "betting_line_id", null: false
    t.datetime "created_at", null: false
    t.bigint "game_id", null: false
    t.decimal "line_value_at_placement", precision: 8, scale: 2
    t.text "metadata"
    t.decimal "odds_at_placement", precision: 8, scale: 2, null: false
    t.decimal "potential_payout", precision: 10, scale: 2, null: false
    t.string "selection", null: false
    t.datetime "settled_at"
    t.text "settlement_notes"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["betting_line_id"], name: "index_bets_on_betting_line_id"
    t.index ["created_at"], name: "index_bets_on_created_at"
    t.index ["game_id", "status"], name: "index_bets_on_game_id_and_status"
    t.index ["game_id"], name: "index_bets_on_game_id"
    t.index ["user_id", "status"], name: "index_bets_on_user_id_and_status"
    t.index ["user_id"], name: "index_bets_on_user_id"
  end

  create_table "betting_lines", force: :cascade do |t|
    t.decimal "away_odds", precision: 8, scale: 2
    t.integer "bets_count", default: 0, null: false
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

  create_table "job_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "executed_at", null: false
    t.string "job_name", null: false
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["job_name", "executed_at"], name: "index_job_executions_on_job_name_and_executed_at"
    t.index ["job_name"], name: "index_job_executions_on_job_name"
  end

  create_table "paper_trading_accounts", force: :cascade do |t|
    t.decimal "balance", precision: 10, scale: 2, default: "1000.0", null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "USD", null: false
    t.string "customer_id", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_paper_trading_accounts_on_customer_id", unique: true
  end

  create_table "paper_trading_transactions", force: :cascade do |t|
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "USD", null: false
    t.text "metadata"
    t.bigint "paper_trading_account_id", null: false
    t.string "transaction_id", null: false
    t.string "transaction_type", null: false
    t.datetime "updated_at", null: false
    t.index ["paper_trading_account_id"], name: "index_paper_trading_transactions_on_paper_trading_account_id"
    t.index ["transaction_id"], name: "index_paper_trading_transactions_on_transaction_id", unique: true
    t.index ["transaction_type"], name: "index_paper_trading_transactions_on_transaction_type"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
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
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "bankroll_transactions", "bankrolls"
  add_foreign_key "bankrolls", "users"
  add_foreign_key "bets", "betting_lines"
  add_foreign_key "bets", "games"
  add_foreign_key "bets", "users"
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
