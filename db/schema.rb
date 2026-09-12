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

ActiveRecord::Schema[8.1].define(version: 2026_09_13_100000) do
  create_table "buildings", id: :string, force: :cascade do |t|
    t.string "gazetteer_version_id", null: false
    t.bigint "ingest_id", null: false
    t.float "lat", null: false
    t.float "lng", null: false
    t.integer "number", null: false
    t.string "unit_code", null: false
    t.index ["gazetteer_version_id", "ingest_id"], name: "index_buildings_on_gazetteer_version_id_and_ingest_id", unique: true
    t.index ["gazetteer_version_id", "unit_code", "number"], name: "idx_on_gazetteer_version_id_unit_code_number_653716156f", unique: true
    t.index ["gazetteer_version_id"], name: "index_buildings_on_gazetteer_version_id"
  end

  create_table "changesets", id: :string, force: :cascade do |t|
    t.datetime "applied_at"
    t.string "applied_in_version"
    t.json "churn"
    t.datetime "created_at", null: false
    t.json "export", default: {}, null: false
    t.datetime "exported_at"
    t.string "exported_by_id"
    t.string "gazetteer_version_id", null: false
    t.integer "status", default: 0, null: false
    t.json "summary", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["exported_by_id"], name: "index_changesets_on_exported_by_id"
    t.index ["gazetteer_version_id", "status"], name: "index_changesets_on_gazetteer_version_id_and_status"
    t.index ["gazetteer_version_id"], name: "index_changesets_on_gazetteer_version_id"
  end

  create_table "contributions", id: :string, force: :cascade do |t|
    t.string "building_id"
    t.string "changeset_id"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "device_id", null: false
    t.string "gazetteer_version_id", null: false
    t.integer "kind", null: false
    t.float "lat"
    t.float "lng"
    t.string "mutation_id", null: false
    t.json "payload", default: {}, null: false
    t.text "review_note"
    t.datetime "reviewed_at"
    t.string "reviewed_by_id"
    t.integer "status", default: 0, null: false
    t.string "target_code"
    t.integer "target_kind", null: false
    t.datetime "updated_at", null: false
    t.string "user_id"
    t.integer "version", default: 1, null: false
    t.index ["building_id"], name: "index_contributions_on_building_id"
    t.index ["changeset_id"], name: "index_contributions_on_changeset_id"
    t.index ["device_id", "mutation_id"], name: "index_contributions_on_device_id_and_mutation_id", unique: true
    t.index ["device_id"], name: "index_contributions_on_device_id"
    t.index ["gazetteer_version_id"], name: "index_contributions_on_gazetteer_version_id"
    t.index ["reviewed_by_id"], name: "index_contributions_on_reviewed_by_id"
    t.index ["status", "kind"], name: "index_contributions_on_status_and_kind"
    t.index ["target_code"], name: "index_contributions_on_target_code"
    t.index ["user_id"], name: "index_contributions_on_user_id"
  end

  create_table "devices", id: :string, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "first_seen_at", null: false
    t.datetime "last_seen_at", null: false
    t.string "token_digest", limit: 64, null: false
    t.datetime "updated_at", null: false
    t.string "user_id"
    t.index ["token_digest"], name: "index_devices_on_token_digest", unique: true
    t.index ["user_id"], name: "index_devices_on_user_id"
  end

  create_table "flipper_features", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_flipper_features_on_key", unique: true
  end

  create_table "flipper_gates", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "feature_key", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.text "value"
    t.index ["feature_key", "key", "value"], name: "index_flipper_gates_on_feature_key_and_key_and_value", unique: true
  end

  create_table "gazetteer_versions", id: :string, force: :cascade do |t|
    t.string "area", null: false
    t.integer "buildings_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "imported_at", null: false
    t.json "names", default: {}, null: false
    t.string "sha256", limit: 64, null: false
    t.integer "units_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.string "version", null: false
    t.index ["sha256"], name: "index_gazetteer_versions_on_sha256", unique: true
    t.index ["version"], name: "index_gazetteer_versions_on_version", unique: true
  end

  create_table "places", id: :string, force: :cascade do |t|
    t.float "centroid_lat", null: false
    t.float "centroid_lng", null: false
    t.string "code", null: false
    t.string "gazetteer_version_id", null: false
    t.string "name"
    t.string "parent_code"
    t.integer "structures", default: 0, null: false
    t.integer "tier", null: false
    t.index ["gazetteer_version_id", "code"], name: "index_places_on_gazetteer_version_id_and_code", unique: true
    t.index ["gazetteer_version_id", "tier"], name: "index_places_on_gazetteer_version_id_and_tier"
    t.index ["gazetteer_version_id"], name: "index_places_on_gazetteer_version_id"
  end

  create_table "sessions", id: :string, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.string "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", id: :string, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "display_name"
    t.string "email_address", null: false
    t.datetime "last_seen_at"
    t.string "password_digest", null: false
    t.integer "reputation", default: 0, null: false
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  create_table "votes", id: :string, force: :cascade do |t|
    t.string "contribution_id", null: false
    t.datetime "created_at", null: false
    t.string "device_id", null: false
    t.integer "stance", null: false
    t.datetime "updated_at", null: false
    t.string "user_id"
    t.index ["contribution_id", "device_id"], name: "index_votes_on_contribution_id_and_device_id", unique: true
    t.index ["contribution_id", "user_id"], name: "index_votes_on_contribution_id_and_user_id", unique: true
    t.index ["contribution_id"], name: "index_votes_on_contribution_id"
    t.index ["device_id"], name: "index_votes_on_device_id"
    t.index ["user_id"], name: "index_votes_on_user_id"
  end

  add_foreign_key "buildings", "gazetteer_versions"
  add_foreign_key "changesets", "gazetteer_versions"
  add_foreign_key "changesets", "users", column: "exported_by_id"
  add_foreign_key "contributions", "buildings"
  add_foreign_key "contributions", "changesets"
  add_foreign_key "contributions", "devices"
  add_foreign_key "contributions", "gazetteer_versions"
  add_foreign_key "contributions", "users"
  add_foreign_key "contributions", "users", column: "reviewed_by_id"
  add_foreign_key "devices", "users"
  add_foreign_key "places", "gazetteer_versions"
  add_foreign_key "sessions", "users"
  add_foreign_key "votes", "contributions"
  add_foreign_key "votes", "devices"
  add_foreign_key "votes", "users"
end
