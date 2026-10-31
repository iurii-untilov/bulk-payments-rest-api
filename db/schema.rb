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

ActiveRecord::Schema[8.1].define(version: 2026_10_31_100005) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "api_keys", force: :cascade do |t|
    t.bigint "firm_id", null: false
    t.text "token_digest", null: false
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["firm_id"], name: "index_api_keys_on_firm_id"
    t.index ["token_digest"], name: "index_api_keys_on_token_digest", unique: true
  end

  create_table "firms", force: :cascade do |t|
    t.text "name", null: false
    t.bigint "balance_cents", default: 0, null: false
    t.text "uuid", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["uuid"], name: "index_firms_on_uuid", unique: true
    t.check_constraint "balance_cents >= 0", name: "firms_balance_cents_non_negative"
  end

  create_table "idempotency_keys", force: :cascade do |t|
    t.bigint "firm_id", null: false
    t.text "key", null: false
    t.text "request_digest", null: false
    t.integer "response_status", null: false
    t.jsonb "response_body", null: false
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.index ["firm_id", "key"], name: "index_idempotency_keys_on_firm_id_and_key", unique: true
  end

  create_table "payments", force: :cascade do |t|
    t.bigint "payer_firm_id", null: false
    t.bigint "payee_firm_id", null: false
    t.bigint "amount_cents", null: false
    t.text "description", null: false
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.index ["payee_firm_id"], name: "index_payments_on_payee_firm_id"
    t.index ["payer_firm_id"], name: "index_payments_on_payer_firm_id"
    t.check_constraint "amount_cents > 0", name: "payments_amount_cents_positive"
    t.check_constraint "payer_firm_id <> payee_firm_id", name: "payments_payer_differs_from_payee"
  end

  add_foreign_key "api_keys", "firms"
  add_foreign_key "idempotency_keys", "firms"
  add_foreign_key "payments", "firms", column: "payee_firm_id"
  add_foreign_key "payments", "firms", column: "payer_firm_id"
end
