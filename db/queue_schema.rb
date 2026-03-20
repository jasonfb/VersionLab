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

ActiveRecord::Schema[8.1].define(version: 2026_03_20_000002) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  # Custom types defined in this database.
  # Note that some types may not work with other database engines. Be careful if changing database.
  create_enum "ai_log_call_type", ["email", "campaign_summary", "email_summary"]
  create_enum "asset_standardized_ratio", ["hero_3_1", "banner_2_1", "widescreen_16_9", "square_1_1", "portrait_4_5"]
  create_enum "autolink_link_mode", ["user_url", "ai_decide"]
  create_enum "autolink_mode", ["none", "link_relevant_text"]
  create_enum "campaign_ai_summary_state", ["idle", "generating", "generated", "failed"]
  create_enum "campaign_status", ["draft", "active", "completed", "archived"]
  create_enum "email_state", ["setup", "pending", "merged", "regenerating"]
  create_enum "email_version_state", ["generating", "active", "rejected"]
  create_enum "template_import_state", ["pending", "processing", "completed", "failed"]
  create_enum "template_import_type", ["bundled", "external"]
  create_enum "template_variable_image_location", ["hero", "banner", "sidebar", "inline", "footer"]
  create_enum "template_variable_slot_role", ["teaser_text", "eyebrow", "headline", "subheadline", "body", "cta_text", "image"]

  create_table "account_users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id"
    t.datetime "created_at", null: false
    t.boolean "is_admin", default: false, null: false
    t.boolean "is_billing_admin", default: false, null: false
    t.boolean "is_owner"
    t.datetime "updated_at", null: false
    t.uuid "user_id"
  end

  create_table "accounts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "is_agency", default: false, null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "active_storage_attachments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
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

  create_table "active_storage_variant_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "ai_keys", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "ai_service_id", null: false
    t.text "api_key", null: false
    t.datetime "created_at", null: false
    t.string "label"
    t.datetime "updated_at", null: false
    t.index ["account_id", "ai_service_id"], name: "index_ai_keys_on_account_id_and_ai_service_id", unique: true
  end

  create_table "ai_logs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "ai_model_id"
    t.uuid "ai_service_id"
    t.enum "call_type", null: false, enum_type: "ai_log_call_type"
    t.integer "completion_tokens"
    t.datetime "created_at", null: false
    t.uuid "loggable_id"
    t.string "loggable_type"
    t.text "prompt"
    t.integer "prompt_tokens"
    t.text "response"
    t.integer "total_tokens"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_ai_logs_on_account_id"
    t.index ["created_at"], name: "index_ai_logs_on_created_at"
    t.index ["loggable_type", "loggable_id"], name: "idx_ai_logs_on_loggable"
  end

  create_table "ai_models", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "ai_service_id", null: false
    t.string "api_identifier", null: false
    t.datetime "created_at", null: false
    t.boolean "for_image", default: false, null: false
    t.boolean "for_text", default: false, null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["ai_service_id"], name: "index_ai_models_on_ai_service_id"
  end

  create_table "ai_services", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_ai_services_on_slug", unique: true
  end

  create_table "assets", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "client_id", null: false
    t.datetime "created_at", null: false
    t.string "folder"
    t.integer "height"
    t.string "name"
    t.enum "standardized_ratio", enum_type: "asset_standardized_ratio"
    t.datetime "updated_at", null: false
    t.integer "width"
    t.index ["client_id"], name: "index_assets_on_client_id"
  end

  create_table "audiences", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "client_id", null: false
    t.datetime "created_at", null: false
    t.text "creative_and_imagery_rules"
    t.text "demographics_and_financial_capacity"
    t.text "details"
    t.text "executive_summary"
    t.text "lapse_diagnosis"
    t.text "motivational_drivers_and_messaging_framework"
    t.string "name", null: false
    t.text "prohibited_patterns"
    t.text "relationship_state_and_pre_lapse_indicators"
    t.text "risk_scoring_model"
    t.text "strategic_reactivation_and_upgrade_cadence"
    t.text "success_indicators_and_macro_trends"
    t.datetime "updated_at", null: false
  end

  create_table "brand_profile_geographies", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "brand_profile_id", null: false
    t.datetime "created_at", null: false
    t.uuid "geography_id", null: false
    t.datetime "updated_at", null: false
    t.index ["brand_profile_id", "geography_id"], name: "idx_bp_geographies", unique: true
  end

  create_table "brand_profile_primary_audiences", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "brand_profile_id", null: false
    t.datetime "created_at", null: false
    t.uuid "primary_audience_id", null: false
    t.datetime "updated_at", null: false
    t.index ["brand_profile_id", "primary_audience_id"], name: "idx_bp_primary_audiences", unique: true
  end

  create_table "brand_profile_tone_rules", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "brand_profile_id", null: false
    t.datetime "created_at", null: false
    t.uuid "tone_rule_id", null: false
    t.datetime "updated_at", null: false
    t.index ["brand_profile_id", "tone_rule_id"], name: "idx_bp_tone_rules", unique: true
  end

  create_table "brand_profiles", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "approved_vocabulary", default: [], array: true
    t.text "blocked_vocabulary", default: [], array: true
    t.uuid "client_id", null: false
    t.text "color_palette", default: [], array: true
    t.text "core_programs", default: [], array: true
    t.datetime "created_at", null: false
    t.uuid "industry_id"
    t.text "mission_statement"
    t.string "organization_name"
    t.uuid "organization_type_id"
    t.string "primary_domain"
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_brand_profiles_on_client_id", unique: true
  end

  create_table "campaign_documents", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "campaign_id", null: false
    t.text "content_text"
    t.datetime "created_at", null: false
    t.string "display_name", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_id"], name: "index_campaign_documents_on_campaign_id"
  end

  create_table "campaign_links", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "campaign_id", null: false
    t.datetime "created_at", null: false
    t.datetime "fetched_at"
    t.text "image_url"
    t.text "link_description"
    t.string "title"
    t.datetime "updated_at", null: false
    t.text "url", null: false
    t.index ["campaign_id"], name: "index_campaign_links_on_campaign_id"
  end

  create_table "campaigns", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "ai_summary"
    t.datetime "ai_summary_generated_at"
    t.enum "ai_summary_state", default: "idle", null: false, enum_type: "campaign_ai_summary_state"
    t.uuid "client_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.date "end_date"
    t.text "goals"
    t.string "name", null: false
    t.date "start_date"
    t.enum "status", default: "draft", null: false, enum_type: "campaign_status"
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_campaigns_on_client_id"
  end

  create_table "client_users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "client_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["client_id", "user_id"], name: "index_client_users_on_client_id_and_user_id", unique: true
  end

  create_table "clients", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.datetime "created_at", null: false
    t.boolean "hidden", default: false, null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  create_table "data_migrations", id: false, force: :cascade do |t|
    t.string "version"
  end

  create_table "email_audiences", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "audience_id", null: false
    t.datetime "created_at", null: false
    t.uuid "email_id", null: false
    t.datetime "updated_at", null: false
  end

  create_table "email_documents", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "content_text"
    t.datetime "created_at", null: false
    t.string "display_name", null: false
    t.uuid "email_id", null: false
    t.datetime "updated_at", null: false
    t.index ["email_id"], name: "index_email_documents_on_email_id"
  end

  create_table "email_section_autolink_settings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.enum "autolink_mode", default: "none", null: false, enum_type: "autolink_mode"
    t.boolean "bold_links", default: false, null: false
    t.datetime "created_at", null: false
    t.uuid "email_id", null: false
    t.uuid "email_template_section_id", null: false
    t.text "group_purpose"
    t.boolean "italic_links", default: false, null: false
    t.string "link_color"
    t.enum "link_mode", enum_type: "autolink_link_mode"
    t.boolean "override_brand_link_styling", default: false, null: false
    t.boolean "underline_links", default: false, null: false
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["email_id", "email_template_section_id"], name: "idx_on_email_id_email_template_section_id_74badd651c", unique: true
  end

  create_table "email_template_sections", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "element_selector"
    t.uuid "email_template_id", null: false
    t.string "name"
    t.uuid "parent_id"
    t.integer "position", null: false
    t.datetime "updated_at", null: false
    t.index ["email_template_id", "position"], name: "idx_on_email_template_id_position_c662290fc5"
  end

  create_table "email_templates", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "client_id", null: false
    t.datetime "created_at", null: false
    t.string "name"
    t.text "original_raw_source_html"
    t.text "raw_source_html"
    t.datetime "updated_at", null: false
  end

  create_table "email_version_variables", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "email_version_id", null: false
    t.uuid "template_variable_id", null: false
    t.datetime "updated_at", null: false
    t.text "value", null: false
    t.index ["email_version_id", "template_variable_id"], name: "idx_merge_version_variables_unique", unique: true
  end

  create_table "email_versions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "ai_model_id", null: false
    t.uuid "ai_service_id", null: false
    t.uuid "audience_id", null: false
    t.datetime "created_at", null: false
    t.uuid "email_id", null: false
    t.text "rejection_comment"
    t.enum "state", default: "generating", null: false, enum_type: "email_version_state"
    t.datetime "updated_at", null: false
    t.integer "version_number", default: 1, null: false
    t.index ["email_id", "audience_id", "version_number"], name: "idx_merge_versions_unique", unique: true
    t.index ["email_id", "audience_id"], name: "idx_merge_versions_on_merge_and_audience"
  end

  create_table "emails", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "ai_model_id"
    t.uuid "ai_service_id"
    t.text "ai_summary"
    t.datetime "ai_summary_generated_at", precision: nil
    t.enum "ai_summary_state", default: "idle", null: false, enum_type: "campaign_ai_summary_state"
    t.uuid "campaign_id"
    t.uuid "client_id", null: false
    t.text "context"
    t.datetime "created_at", null: false
    t.uuid "email_template_id", null: false
    t.enum "state", default: "setup", null: false, enum_type: "email_state"
    t.datetime "updated_at", null: false
    t.index ["campaign_id"], name: "index_emails_on_campaign_id"
    t.index ["client_id"], name: "index_emails_on_client_id"
  end

  create_table "geographies", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
  end

  create_table "industries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
  end

  create_table "organization_types", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
  end

  create_table "primary_audiences", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
  end

  create_table "roles", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "label"
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", null: false
    t.bigint "channel_hash", null: false
    t.datetime "created_at", null: false
    t.binary "payload", null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.integer "byte_size", null: false
    t.datetime "created_at", null: false
    t.binary "key", null: false
    t.bigint "key_hash", null: false
    t.binary "value", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
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

  create_table "template_imports", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "email_template_id", null: false
    t.text "error_message"
    t.enum "import_type", null: false, enum_type: "template_import_type"
    t.enum "state", default: "pending", null: false, enum_type: "template_import_state"
    t.datetime "updated_at", null: false
    t.text "warnings"
    t.index ["email_template_id"], name: "index_template_imports_on_email_template_id"
  end

  create_table "template_variables", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "default_value", null: false
    t.uuid "email_template_section_id", null: false
    t.enum "image_location", enum_type: "template_variable_image_location"
    t.string "name", null: false
    t.integer "position", null: false
    t.enum "slot_role", enum_type: "template_variable_slot_role"
    t.datetime "updated_at", null: false
    t.string "variable_type", default: "text", null: false
    t.integer "word_count"
    t.index ["email_template_section_id", "position"], name: "idx_on_email_template_section_id_position_ec7798dbd9"
  end

  create_table "tone_rules", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
  end

  create_table "user_roles", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "role_id"
    t.datetime "updated_at", null: false
    t.uuid "user_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "name"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "ai_logs", "accounts"
  add_foreign_key "assets", "clients"
  add_foreign_key "brand_profile_geographies", "brand_profiles"
  add_foreign_key "brand_profile_geographies", "geographies"
  add_foreign_key "brand_profile_primary_audiences", "brand_profiles"
  add_foreign_key "brand_profile_primary_audiences", "primary_audiences"
  add_foreign_key "brand_profile_tone_rules", "brand_profiles"
  add_foreign_key "brand_profile_tone_rules", "tone_rules"
  add_foreign_key "brand_profiles", "clients"
  add_foreign_key "brand_profiles", "industries"
  add_foreign_key "brand_profiles", "organization_types"
  add_foreign_key "campaign_documents", "campaigns"
  add_foreign_key "campaign_links", "campaigns"
  add_foreign_key "campaigns", "clients"
  add_foreign_key "email_documents", "emails"
  add_foreign_key "emails", "campaigns"
  add_foreign_key "emails", "clients"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "template_imports", "email_templates"
end
