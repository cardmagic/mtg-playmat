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

ActiveRecord::Schema[8.1].define(version: 2026_08_13_182035) do
  create_table "solid_objects_broadcasts", force: :cascade do |t|
    t.bigint "activation_generation", null: false
    t.integer "attempt_count", default: 0, null: false
    t.datetime "available_at", null: false
    t.string "broadcast_id", limit: 36, null: false
    t.datetime "claimed_at"
    t.string "claimed_by", limit: 36
    t.datetime "created_at", null: false
    t.datetime "delivered_at"
    t.json "error"
    t.integer "instance_id", null: false
    t.integer "message_id", null: false
    t.string "observable_name", limit: 191, null: false
    t.integer "state_version", null: false
    t.string "status", limit: 32, default: "pending", null: false
    t.datetime "updated_at", null: false
    t.json "value", null: false
    t.index ["broadcast_id"], name: "idx_so_broadcasts_id", unique: true
    t.index ["claimed_by", "claimed_at"], name: "idx_so_broadcasts_claim"
    t.index ["delivered_at", "id"], name: "idx_so_broadcasts_cleanup"
    t.index ["instance_id"], name: "index_solid_objects_broadcasts_on_instance_id"
    t.index ["message_id", "observable_name"], name: "idx_so_broadcasts_observable", unique: true
    t.index ["message_id"], name: "index_solid_objects_broadcasts_on_message_id"
    t.index ["status", "available_at", "id"], name: "idx_so_broadcasts_poll"
    t.check_constraint "activation_generation > 0", name: "chk_so_broadcasts_generation"
    t.check_constraint "attempt_count >= 0", name: "chk_so_broadcasts_attempt"
    t.check_constraint "state_version > 0", name: "chk_so_broadcasts_version"
    t.check_constraint "status IN ('pending', 'processing', 'delivered', 'dead')", name: "chk_so_broadcasts_status"
  end

  create_table "solid_objects_claimed_messages", force: :cascade do |t|
    t.bigint "activation_generation", null: false
    t.string "activation_token", limit: 36
    t.datetime "claimed_at", null: false
    t.integer "instance_id", null: false
    t.integer "message_id", null: false
    t.string "process_id", limit: 36
    t.index ["instance_id"], name: "idx_so_claimed_instance", unique: true
    t.index ["instance_id"], name: "index_solid_objects_claimed_messages_on_instance_id"
    t.index ["message_id"], name: "idx_so_claimed_message", unique: true
    t.index ["message_id"], name: "index_solid_objects_claimed_messages_on_message_id"
    t.index ["process_id", "claimed_at"], name: "idx_so_claimed_process"
    t.check_constraint "activation_generation > 0", name: "chk_so_claimed_generation"
    t.check_constraint "process_id IS NULL OR activation_token IS NOT NULL", name: "chk_so_claimed_activation_owner"
  end

  create_table "solid_objects_dead_letters", force: :cascade do |t|
    t.string "actor_id", limit: 191, null: false
    t.string "actor_type", limit: 191, null: false
    t.json "arguments", null: false
    t.integer "attempts", null: false
    t.json "backtrace", null: false
    t.datetime "created_at", null: false
    t.string "exception_class", limit: 255, null: false
    t.text "exception_message", null: false
    t.datetime "first_failed_at", null: false
    t.integer "instance_id", null: false
    t.datetime "last_failed_at", null: false
    t.integer "message_id", null: false
    t.string "operation", limit: 191, null: false
    t.bigint "retried_message_id"
    t.datetime "updated_at", null: false
    t.index ["actor_type", "actor_id", "last_failed_at"], name: "idx_so_dead_letters_actor"
    t.index ["instance_id"], name: "index_solid_objects_dead_letters_on_instance_id"
    t.index ["last_failed_at", "id"], name: "idx_so_dead_letters_cleanup"
    t.index ["message_id"], name: "idx_so_dead_letters_message", unique: true
    t.index ["message_id"], name: "index_solid_objects_dead_letters_on_message_id"
    t.check_constraint "attempts > 0", name: "chk_so_dead_letters_attempts"
  end

  create_table "solid_objects_effects", force: :cascade do |t|
    t.json "arguments", null: false
    t.integer "attempt_count", default: 0, null: false
    t.datetime "available_at", null: false
    t.datetime "claimed_at"
    t.string "claimed_by", limit: 36
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.string "effect_id", limit: 36, null: false
    t.json "error"
    t.string "failure_operation", limit: 191
    t.integer "instance_id", null: false
    t.integer "max_attempts", null: false
    t.integer "message_id", null: false
    t.string "name", limit: 191, null: false
    t.json "result"
    t.string "status", limit: 32, default: "pending", null: false
    t.string "success_operation", limit: 191
    t.datetime "updated_at", null: false
    t.index ["completed_at", "id"], name: "idx_so_effects_cleanup"
    t.index ["effect_id"], name: "idx_so_effects_effect_id", unique: true
    t.index ["instance_id"], name: "index_solid_objects_effects_on_instance_id"
    t.index ["message_id"], name: "index_solid_objects_effects_on_message_id"
    t.index ["status", "available_at", "id"], name: "idx_so_effects_poll"
    t.check_constraint "attempt_count >= 0", name: "chk_so_effects_attempt"
    t.check_constraint "max_attempts > 0", name: "chk_so_effects_max_attempts"
    t.check_constraint "status IN ('pending', 'processing', 'completed', 'dead')", name: "chk_so_effects_status"
  end

  create_table "solid_objects_instances", force: :cascade do |t|
    t.datetime "activated_at"
    t.datetime "activation_expires_at"
    t.bigint "activation_generation", default: 0, null: false
    t.string "activation_owner_id", limit: 36
    t.string "activation_token", limit: 36
    t.string "actor_id", limit: 191, null: false
    t.string "actor_type", limit: 191, null: false
    t.datetime "created_at", null: false
    t.datetime "last_claimed_at"
    t.datetime "last_used_at"
    t.bigint "next_message_sequence", default: 1, null: false
    t.datetime "paused_at"
    t.json "state", null: false
    t.bigint "state_revision", default: 0, null: false
    t.integer "state_version", default: 1, null: false
    t.datetime "updated_at", null: false
    t.index ["activation_expires_at", "last_claimed_at", "id"], name: "idx_so_instances_lease"
    t.index ["activation_owner_id"], name: "idx_so_instances_owner"
    t.index ["actor_type", "actor_id"], name: "idx_so_instances_identity", unique: true
    t.index ["last_used_at", "id"], name: "idx_so_instances_cleanup"
    t.check_constraint "(activation_owner_id IS NULL AND activation_token IS NULL) OR (activation_owner_id IS NOT NULL AND activation_token IS NOT NULL)", name: "chk_so_instances_activation_owner"
    t.check_constraint "activation_generation >= 0", name: "chk_so_instances_generation"
    t.check_constraint "next_message_sequence > 0", name: "chk_so_instances_sequence"
    t.check_constraint "state_version > 0", name: "chk_so_instances_state_version"
  end

  create_table "solid_objects_messages", force: :cascade do |t|
    t.string "actor_id", limit: 191, null: false
    t.string "actor_type", limit: 191, null: false
    t.json "arguments", null: false
    t.integer "attempt_count", default: 0, null: false
    t.datetime "available_at", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.string "delivery_mode", limit: 32, null: false
    t.datetime "enqueued_at", null: false
    t.json "error"
    t.string "idempotency_key", limit: 191
    t.integer "instance_id", null: false
    t.datetime "last_failed_at"
    t.integer "max_attempts", null: false
    t.string "operation", limit: 191, null: false
    t.datetime "rejected_at"
    t.json "rejection"
    t.string "request_id", limit: 36, null: false
    t.json "result"
    t.bigint "sequence", null: false
    t.datetime "started_at"
    t.datetime "updated_at", null: false
    t.index ["actor_type", "actor_id", "sequence"], name: "idx_so_messages_actor_sequence", unique: true
    t.index ["completed_at", "id"], name: "idx_so_messages_cleanup"
    t.index ["instance_id", "idempotency_key"], name: "idx_so_messages_idempotency", unique: true
    t.index ["instance_id", "sequence"], name: "idx_so_messages_instance_sequence", unique: true
    t.index ["instance_id"], name: "index_solid_objects_messages_on_instance_id"
    t.index ["rejected_at", "id"], name: "idx_so_messages_rejected"
    t.index ["request_id"], name: "idx_so_messages_request", unique: true
    t.check_constraint "attempt_count >= 0", name: "chk_so_messages_attempt"
    t.check_constraint "delivery_mode IN ('async', 'sync', 'internal')", name: "chk_so_messages_delivery_mode"
    t.check_constraint "max_attempts > 0", name: "chk_so_messages_max_attempts"
    t.check_constraint "sequence > 0", name: "chk_so_messages_sequence"
  end

  create_table "solid_objects_processes", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname", limit: 255, null: false
    t.string "kind", limit: 64, null: false
    t.datetime "last_heartbeat_at", null: false
    t.json "metadata", null: false
    t.bigint "pid", null: false
    t.datetime "shutdown_requested_at"
    t.string "shutdown_state", limit: 32, default: "running", null: false
    t.datetime "started_at", null: false
    t.datetime "stopped_at"
    t.datetime "updated_at", null: false
    t.index ["kind", "shutdown_state"], name: "idx_so_processes_kind"
    t.index ["shutdown_state", "last_heartbeat_at"], name: "idx_so_processes_liveness"
    t.check_constraint "shutdown_state IN ('running', 'draining', 'stopped')", name: "chk_so_process_shutdown"
  end

  create_table "solid_objects_ready_messages", force: :cascade do |t|
    t.datetime "available_at", null: false
    t.datetime "created_at", null: false
    t.integer "instance_id", null: false
    t.integer "message_id", null: false
    t.bigint "sequence", null: false
    t.index ["available_at", "instance_id", "sequence"], name: "idx_so_ready_poll"
    t.index ["instance_id", "sequence"], name: "idx_so_ready_instance_sequence", unique: true
    t.index ["instance_id"], name: "index_solid_objects_ready_messages_on_instance_id"
    t.index ["message_id"], name: "idx_so_ready_message", unique: true
    t.index ["message_id"], name: "index_solid_objects_ready_messages_on_message_id"
    t.check_constraint "sequence > 0", name: "chk_so_ready_sequence"
  end

  create_table "solid_objects_reminders", force: :cascade do |t|
    t.string "actor_id", limit: 191, null: false
    t.string "actor_type", limit: 191, null: false
    t.json "arguments", null: false
    t.datetime "claimed_at"
    t.string "claimed_by", limit: 36
    t.datetime "created_at", null: false
    t.integer "instance_id", null: false
    t.decimal "interval_seconds", precision: 20, scale: 6
    t.string "missed_policy", limit: 32, default: "latest", null: false
    t.string "name", limit: 191, null: false
    t.datetime "next_run_at", null: false
    t.bigint "occurrence", default: 0, null: false
    t.string "operation", limit: 191, null: false
    t.string "status", limit: 32, default: "scheduled", null: false
    t.datetime "updated_at", null: false
    t.index ["instance_id", "name"], name: "idx_so_reminders_name", unique: true
    t.index ["instance_id"], name: "index_solid_objects_reminders_on_instance_id"
    t.index ["status", "next_run_at", "id"], name: "idx_so_reminders_due"
    t.check_constraint "interval_seconds IS NULL OR interval_seconds > 0", name: "chk_so_reminders_interval"
    t.check_constraint "missed_policy IN ('latest', 'all')", name: "chk_so_reminders_missed"
    t.check_constraint "occurrence >= 0", name: "chk_so_reminders_occurrence"
    t.check_constraint "status IN ('scheduled', 'paused', 'completed')", name: "chk_so_reminders_status"
  end

  add_foreign_key "solid_objects_broadcasts", "solid_objects_instances", column: "instance_id", on_delete: :cascade
  add_foreign_key "solid_objects_broadcasts", "solid_objects_messages", column: "message_id", on_delete: :cascade
  add_foreign_key "solid_objects_broadcasts", "solid_objects_processes", column: "claimed_by", on_delete: :nullify
  add_foreign_key "solid_objects_claimed_messages", "solid_objects_instances", column: "instance_id", on_delete: :cascade
  add_foreign_key "solid_objects_claimed_messages", "solid_objects_messages", column: "message_id", on_delete: :cascade
  add_foreign_key "solid_objects_claimed_messages", "solid_objects_processes", column: "process_id", on_delete: :restrict
  add_foreign_key "solid_objects_dead_letters", "solid_objects_instances", column: "instance_id", on_delete: :cascade
  add_foreign_key "solid_objects_dead_letters", "solid_objects_messages", column: "message_id", on_delete: :cascade
  add_foreign_key "solid_objects_dead_letters", "solid_objects_messages", column: "retried_message_id", on_delete: :nullify
  add_foreign_key "solid_objects_effects", "solid_objects_instances", column: "instance_id", on_delete: :cascade
  add_foreign_key "solid_objects_effects", "solid_objects_messages", column: "message_id", on_delete: :cascade
  add_foreign_key "solid_objects_effects", "solid_objects_processes", column: "claimed_by", on_delete: :nullify
  add_foreign_key "solid_objects_instances", "solid_objects_processes", column: "activation_owner_id", on_delete: :restrict
  add_foreign_key "solid_objects_messages", "solid_objects_instances", column: "instance_id", on_delete: :cascade
  add_foreign_key "solid_objects_ready_messages", "solid_objects_instances", column: "instance_id", on_delete: :cascade
  add_foreign_key "solid_objects_ready_messages", "solid_objects_messages", column: "message_id", on_delete: :cascade
  add_foreign_key "solid_objects_reminders", "solid_objects_instances", column: "instance_id", on_delete: :cascade
  add_foreign_key "solid_objects_reminders", "solid_objects_processes", column: "claimed_by", on_delete: :nullify
end
