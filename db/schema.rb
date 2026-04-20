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

ActiveRecord::Schema[8.1].define(version: 2026_04_18_220000) do
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

  create_table "employee_profiles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "department", null: false
    t.string "employee_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["employee_id"], name: "index_employee_profiles_on_employee_id", unique: true
    t.index ["user_id"], name: "index_employee_profiles_on_user_id"
  end

  create_table "food_items", force: :cascade do |t|
    t.boolean "active", default: true
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.integer "sort_order", default: 0
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_food_items_on_active"
    t.index ["category"], name: "index_food_items_on_category"
  end

  create_table "location_settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "enabled", default: false
    t.decimal "latitude", precision: 10, scale: 6
    t.decimal "longitude", precision: 10, scale: 6
    t.string "name", default: "Office", null: false
    t.integer "radius_meters", default: 100
    t.integer "setting_type", null: false
    t.datetime "updated_at", null: false
    t.index ["setting_type"], name: "index_location_settings_on_setting_type", unique: true
  end

  create_table "meal_settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.time "end_time", null: false
    t.string "meal_type", null: false
    t.decimal "price", precision: 10, scale: 2, default: "0.0", null: false
    t.time "start_time", null: false
    t.datetime "updated_at", null: false
    t.index ["meal_type"], name: "index_meal_settings_on_meal_type", unique: true
  end

  create_table "order_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "food_item_id", null: false
    t.string "item_code"
    t.bigint "order_id", null: false
    t.datetime "redeemed_at"
    t.bigint "redeemed_by_id"
    t.datetime "updated_at", null: false
    t.index ["food_item_id"], name: "index_order_items_on_food_item_id"
    t.index ["item_code"], name: "index_order_items_on_item_code", unique: true
    t.index ["order_id", "food_item_id"], name: "index_order_items_on_order_id_and_food_item_id", unique: true
    t.index ["order_id"], name: "index_order_items_on_order_id"
    t.index ["redeemed_at"], name: "index_order_items_on_redeemed_at"
  end

  create_table "orders", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["date"], name: "index_orders_on_date"
    t.index ["user_id", "date"], name: "index_orders_on_user_id_and_date", unique: true
    t.index ["user_id"], name: "index_orders_on_user_id"
  end

  create_table "redemption_requests", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "order_item_id"
    t.datetime "responded_at"
    t.integer "status", default: 0, null: false
    t.bigint "token_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "vendor_id", null: false
    t.index ["order_item_id", "status"], name: "index_redemption_requests_on_order_item_id_and_status"
    t.index ["order_item_id"], name: "index_redemption_requests_on_order_item_id"
    t.index ["token_id", "status"], name: "index_redemption_requests_on_token_id_and_status"
    t.index ["token_id"], name: "index_redemption_requests_on_token_id"
    t.index ["vendor_id"], name: "index_redemption_requests_on_vendor_id"
  end

  create_table "tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "order_id", null: false
    t.datetime "redeemed_at"
    t.integer "redeemed_by"
    t.integer "status", default: 0, null: false
    t.string "token_number", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_tokens_on_expires_at"
    t.index ["order_id"], name: "index_tokens_on_order_id"
    t.index ["status", "expires_at"], name: "index_tokens_on_status_and_expires_at"
    t.index ["status"], name: "index_tokens_on_status"
    t.index ["token_number"], name: "index_tokens_on_token_number", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.boolean "active", default: true
    t.boolean "admin_created", default: false, null: false
    t.datetime "confirmation_sent_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.datetime "current_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "email", null: false
    t.string "encrypted_password", default: "", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.string "google_avatar_url"
    t.datetime "last_sign_in_at"
    t.string "last_sign_in_ip"
    t.datetime "locked_at"
    t.boolean "must_change_password", default: false, null: false
    t.string "name", null: false
    t.string "phone"
    t.string "provider"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "role", default: 0, null: false
    t.integer "sign_in_count", default: 0, null: false
    t.string "uid"
    t.string "unconfirmed_email"
    t.string "unlock_token"
    t.datetime "updated_at", null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  create_table "vendor_profiles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "stall_name", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "vendor_id", null: false
    t.index ["user_id"], name: "index_vendor_profiles_on_user_id"
    t.index ["vendor_id"], name: "index_vendor_profiles_on_vendor_id", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "employee_profiles", "users"
  add_foreign_key "order_items", "food_items"
  add_foreign_key "order_items", "orders"
  add_foreign_key "orders", "users"
  add_foreign_key "redemption_requests", "order_items"
  add_foreign_key "redemption_requests", "tokens"
  add_foreign_key "redemption_requests", "users", column: "vendor_id"
  add_foreign_key "tokens", "orders"
  add_foreign_key "vendor_profiles", "users"
end
