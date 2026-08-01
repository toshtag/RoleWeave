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

ActiveRecord::Schema[8.1].define(version: 2026_08_01_161325) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "authentication_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "ip_address"
    t.string "kind", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id"
    t.index ["email_address", "created_at"], name: "index_authentication_events_on_email_address_and_created_at"
    t.index ["user_id", "created_at"], name: "index_authentication_events_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_authentication_events_on_user_id"
  end

  create_table "candidate_profiles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "desired_occupation"
    t.string "display_name", null: false
    t.text "introduction"
    t.string "location"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_candidate_profiles_on_user_id", unique: true
  end

  create_table "invitations", force: :cascade do |t|
    t.datetime "accepted_at"
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.bigint "invited_by_id"
    t.bigint "organization_id", null: false
    t.string "role", null: false
    t.datetime "updated_at", null: false
    t.index ["invited_by_id"], name: "index_invitations_on_invited_by_id"
    t.index ["organization_id", "email_address"], name: "index_pending_invitations_on_organization_and_email", unique: true, where: "(accepted_at IS NULL)"
    t.index ["organization_id"], name: "index_invitations_on_organization_id"
  end

  create_table "job_posting_events", force: :cascade do |t|
    t.bigint "changed_by_id"
    t.datetime "created_at", null: false
    t.string "from_status"
    t.bigint "job_posting_id"
    t.string "job_posting_title", null: false
    t.bigint "organization_id"
    t.string "to_status", null: false
    t.datetime "updated_at", null: false
    t.index ["changed_by_id"], name: "index_job_posting_events_on_changed_by_id"
    t.index ["job_posting_id"], name: "index_job_posting_events_on_job_posting_id"
    t.index ["organization_id", "created_at"], name: "index_job_posting_events_on_organization_id_and_created_at"
    t.index ["organization_id"], name: "index_job_posting_events_on_organization_id"
  end

  create_table "job_postings", force: :cascade do |t|
    t.integer "annual_salary_max"
    t.integer "annual_salary_min"
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.string "employment_type"
    t.string "location"
    t.string "occupation"
    t.bigint "organization_id", null: false
    t.text "requirements"
    t.string "salary"
    t.string "salary_currency"
    t.string "status", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "status", "created_at"], name: "idx_on_organization_id_status_created_at_dbef991872"
    t.index ["organization_id"], name: "index_job_postings_on_organization_id"
    t.index ["salary_currency", "annual_salary_min"], name: "index_job_postings_on_salary_currency_and_annual_salary_min"
  end

  create_table "membership_events", force: :cascade do |t|
    t.bigint "changed_by_id"
    t.datetime "created_at", null: false
    t.string "from_role"
    t.string "kind", null: false
    t.bigint "organization_id"
    t.string "to_role", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["changed_by_id"], name: "index_membership_events_on_changed_by_id"
    t.index ["organization_id", "created_at"], name: "index_membership_events_on_organization_id_and_created_at"
    t.index ["organization_id"], name: "index_membership_events_on_organization_id"
    t.index ["user_id"], name: "index_membership_events_on_user_id"
  end

  create_table "memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "organization_id", null: false
    t.string "role", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["organization_id", "user_id"], name: "index_memberships_on_organization_id_and_user_id", unique: true
    t.index ["organization_id"], name: "index_memberships_on_organization_id"
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "last_active_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.boolean "operator", default: false, null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "work_experiences", force: :cascade do |t|
    t.bigint "candidate_profile_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.date "ended_on"
    t.string "organization_name", null: false
    t.string "position", null: false
    t.date "started_on", null: false
    t.datetime "updated_at", null: false
    t.index ["candidate_profile_id", "started_on"], name: "index_work_experiences_on_candidate_profile_id_and_started_on"
    t.index ["candidate_profile_id"], name: "index_work_experiences_on_candidate_profile_id"
  end

  add_foreign_key "authentication_events", "users", on_delete: :nullify
  add_foreign_key "candidate_profiles", "users"
  add_foreign_key "invitations", "organizations"
  add_foreign_key "invitations", "users", column: "invited_by_id", on_delete: :nullify
  add_foreign_key "job_posting_events", "job_postings", on_delete: :nullify
  add_foreign_key "job_posting_events", "organizations", on_delete: :nullify
  add_foreign_key "job_posting_events", "users", column: "changed_by_id", on_delete: :nullify
  add_foreign_key "job_postings", "organizations"
  add_foreign_key "membership_events", "organizations", on_delete: :nullify
  add_foreign_key "membership_events", "users", column: "changed_by_id", on_delete: :nullify
  add_foreign_key "membership_events", "users", on_delete: :nullify
  add_foreign_key "memberships", "organizations"
  add_foreign_key "memberships", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "work_experiences", "candidate_profiles"
end
