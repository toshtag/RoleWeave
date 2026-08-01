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

ActiveRecord::Schema[8.1].define(version: 2026_08_01_201606) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "application_reviews", force: :cascade do |t|
    t.text "comment"
    t.datetime "created_at", null: false
    t.bigint "job_application_id", null: false
    t.integer "rating"
    t.bigint "reviewer_id"
    t.datetime "updated_at", null: false
    t.index ["job_application_id", "created_at"], name: "index_application_reviews_on_job_application_id_and_created_at"
    t.index ["job_application_id"], name: "index_application_reviews_on_job_application_id"
    t.index ["reviewer_id"], name: "index_application_reviews_on_reviewer_id"
  end

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
    t.boolean "desired_salary_visible", default: false, null: false
    t.string "display_name", null: false
    t.boolean "documents_visible", default: false, null: false
    t.text "introduction"
    t.string "location"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "visibility", default: "closed", null: false
    t.index ["user_id"], name: "index_candidate_profiles_on_user_id", unique: true
    t.index ["visibility"], name: "index_candidate_profiles_on_visibility"
  end

  create_table "conversations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_application_id", null: false
    t.datetime "updated_at", null: false
    t.index ["job_application_id"], name: "index_conversations_on_job_application_id", unique: true
  end

  create_table "desired_conditions", force: :cascade do |t|
    t.integer "annual_salary_min"
    t.date "available_from"
    t.bigint "candidate_profile_id", null: false
    t.datetime "created_at", null: false
    t.string "employment_type"
    t.string "location"
    t.text "note"
    t.string "salary_currency"
    t.datetime "updated_at", null: false
    t.index ["candidate_profile_id"], name: "index_desired_conditions_on_candidate_profile_id", unique: true
  end

  create_table "educations", force: :cascade do |t|
    t.bigint "candidate_profile_id", null: false
    t.datetime "created_at", null: false
    t.string "degree"
    t.date "ended_on"
    t.string "field_of_study"
    t.string "school_name", null: false
    t.date "started_on", null: false
    t.datetime "updated_at", null: false
    t.index ["candidate_profile_id", "started_on"], name: "index_educations_on_candidate_profile_id_and_started_on"
    t.index ["candidate_profile_id"], name: "index_educations_on_candidate_profile_id"
  end

  create_table "interview_schedules", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.integer "duration_minutes"
    t.bigint "job_application_id", null: false
    t.string "location"
    t.text "note"
    t.datetime "starts_at", null: false
    t.string "status", default: "scheduled", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_interview_schedules_on_created_by_id"
    t.index ["job_application_id", "starts_at"], name: "index_interview_schedules_on_job_application_id_and_starts_at"
    t.index ["job_application_id"], name: "index_interview_schedules_on_job_application_id"
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

  create_table "job_application_events", force: :cascade do |t|
    t.string "candidate_display_name", null: false
    t.bigint "changed_by_id"
    t.datetime "created_at", null: false
    t.string "from_stage"
    t.bigint "job_application_id"
    t.bigint "job_posting_id"
    t.string "job_posting_title", null: false
    t.string "kind", null: false
    t.bigint "organization_id", null: false
    t.string "to_stage"
    t.datetime "updated_at", null: false
    t.index ["changed_by_id"], name: "index_job_application_events_on_changed_by_id"
    t.index ["job_application_id"], name: "index_job_application_events_on_job_application_id"
    t.index ["job_posting_id"], name: "index_job_application_events_on_job_posting_id"
    t.index ["organization_id", "created_at"], name: "index_job_application_events_on_organization_id_and_created_at"
    t.index ["organization_id"], name: "index_job_application_events_on_organization_id"
  end

  create_table "job_applications", force: :cascade do |t|
    t.bigint "assignee_id"
    t.bigint "candidate_profile_id", null: false
    t.jsonb "candidate_profile_snapshot", default: {}, null: false
    t.datetime "created_at", null: false
    t.date "decide_by"
    t.bigint "job_posting_id", null: false
    t.jsonb "job_posting_snapshot", default: {}, null: false
    t.string "stage", default: "screening", null: false
    t.string "status", default: "submitted", null: false
    t.datetime "updated_at", null: false
    t.index ["assignee_id"], name: "index_job_applications_on_assignee_id"
    t.index ["candidate_profile_id", "job_posting_id"], name: "idx_on_candidate_profile_id_job_posting_id_7e5ce60919", unique: true
    t.index ["candidate_profile_id"], name: "index_job_applications_on_candidate_profile_id"
    t.index ["job_posting_id", "stage"], name: "index_job_applications_on_job_posting_id_and_stage"
    t.index ["job_posting_id"], name: "index_job_applications_on_job_posting_id"
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

  create_table "message_reads", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "message_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["message_id", "user_id"], name: "index_message_reads_on_message_id_and_user_id", unique: true
    t.index ["message_id"], name: "index_message_reads_on_message_id"
    t.index ["user_id"], name: "index_message_reads_on_user_id"
  end

  create_table "messages", force: :cascade do |t|
    t.text "body", null: false
    t.bigint "conversation_id", null: false
    t.datetime "created_at", null: false
    t.bigint "sender_id"
    t.datetime "updated_at", null: false
    t.index ["conversation_id", "created_at"], name: "index_messages_on_conversation_id_and_created_at"
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
    t.index ["sender_id"], name: "index_messages_on_sender_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "email_attempts", default: 0, null: false
    t.datetime "email_delivered_at"
    t.text "email_error"
    t.string "email_status", default: "pending", null: false
    t.bigint "job_application_id"
    t.string "kind", null: false
    t.bigint "message_id"
    t.datetime "read_at"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["email_status"], name: "index_notifications_on_email_status"
    t.index ["job_application_id"], name: "index_notifications_on_job_application_id"
    t.index ["message_id"], name: "index_notifications_on_message_id"
    t.index ["user_id", "created_at"], name: "index_notifications_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_notifications_on_user_id"
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

  create_table "skills", force: :cascade do |t|
    t.bigint "candidate_profile_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.integer "years_of_experience"
    t.index ["candidate_profile_id", "name"], name: "index_skills_on_candidate_profile_id_and_name", unique: true
    t.index ["candidate_profile_id"], name: "index_skills_on_candidate_profile_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.boolean "email_notifications", default: true, null: false
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

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "application_reviews", "job_applications"
  add_foreign_key "application_reviews", "users", column: "reviewer_id", on_delete: :nullify
  add_foreign_key "authentication_events", "users", on_delete: :nullify
  add_foreign_key "candidate_profiles", "users"
  add_foreign_key "conversations", "job_applications"
  add_foreign_key "desired_conditions", "candidate_profiles"
  add_foreign_key "educations", "candidate_profiles"
  add_foreign_key "interview_schedules", "job_applications"
  add_foreign_key "interview_schedules", "users", column: "created_by_id", on_delete: :nullify
  add_foreign_key "invitations", "organizations"
  add_foreign_key "invitations", "users", column: "invited_by_id", on_delete: :nullify
  add_foreign_key "job_application_events", "job_applications", on_delete: :nullify
  add_foreign_key "job_application_events", "job_postings", on_delete: :nullify
  add_foreign_key "job_application_events", "organizations"
  add_foreign_key "job_application_events", "users", column: "changed_by_id", on_delete: :nullify
  add_foreign_key "job_applications", "candidate_profiles"
  add_foreign_key "job_applications", "job_postings"
  add_foreign_key "job_applications", "users", column: "assignee_id", on_delete: :nullify
  add_foreign_key "job_posting_events", "job_postings", on_delete: :nullify
  add_foreign_key "job_posting_events", "organizations", on_delete: :nullify
  add_foreign_key "job_posting_events", "users", column: "changed_by_id", on_delete: :nullify
  add_foreign_key "job_postings", "organizations"
  add_foreign_key "membership_events", "organizations", on_delete: :nullify
  add_foreign_key "membership_events", "users", column: "changed_by_id", on_delete: :nullify
  add_foreign_key "membership_events", "users", on_delete: :nullify
  add_foreign_key "memberships", "organizations"
  add_foreign_key "memberships", "users"
  add_foreign_key "message_reads", "messages"
  add_foreign_key "message_reads", "users"
  add_foreign_key "messages", "conversations"
  add_foreign_key "messages", "users", column: "sender_id", on_delete: :nullify
  add_foreign_key "notifications", "job_applications", on_delete: :cascade
  add_foreign_key "notifications", "messages", on_delete: :cascade
  add_foreign_key "notifications", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "skills", "candidate_profiles"
  add_foreign_key "work_experiences", "candidate_profiles"
end
