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

ActiveRecord::Schema[8.1].define(version: 2026_07_15_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "btree_gist"
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

  create_table "amenities", force: :cascade do |t|
    t.integer "category"
    t.datetime "created_at", null: false
    t.string "icon"
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "availabilities", force: :cascade do |t|
    t.boolean "available"
    t.datetime "created_at", null: false
    t.decimal "custom_price"
    t.date "date"
    t.bigint "property_id", null: false
    t.datetime "updated_at", null: false
    t.index ["property_id"], name: "index_availabilities_on_property_id"
  end

  create_table "bookings", force: :cascade do |t|
    t.date "check_in"
    t.date "check_out"
    t.datetime "confirmation_sent_at"
    t.datetime "created_at", null: false
    t.integer "guests_count"
    t.string "invoice_reference"
    t.bigint "property_id", null: false
    t.datetime "reminder_sent_at"
    t.datetime "request_ack_sent_at"
    t.datetime "review_request_sent_at"
    t.text "special_requests"
    t.integer "status"
    t.decimal "total_price"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["property_id"], name: "index_bookings_on_property_id"
    t.index ["user_id"], name: "index_bookings_on_user_id"
    t.exclusion_constraint "property_id WITH =, daterange(check_in, check_out) WITH &&", where: "status = ANY (ARRAY[0, 1])", using: :gist, name: "bookings_no_overlap"
  end

  create_table "contact_submissions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.text "message"
    t.string "name"
    t.integer "status"
    t.string "subject"
    t.datetime "updated_at", null: false
  end

  create_table "conversations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "participant_1_id", null: false
    t.bigint "participant_2_id", null: false
    t.bigint "property_id", null: false
    t.datetime "updated_at", null: false
    t.index ["participant_1_id", "participant_2_id", "property_id"], name: "index_conversations_on_participants_and_property", unique: true
    t.index ["participant_1_id"], name: "index_conversations_on_participant_1_id"
    t.index ["participant_2_id"], name: "index_conversations_on_participant_2_id"
    t.index ["property_id"], name: "index_conversations_on_property_id"
  end

  create_table "favorites", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "property_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["property_id"], name: "index_favorites_on_property_id"
    t.index ["user_id", "property_id"], name: "index_favorites_on_user_id_and_property_id", unique: true
    t.index ["user_id"], name: "index_favorites_on_user_id"
  end

  create_table "messages", force: :cascade do |t|
    t.text "body"
    t.bigint "conversation_id", null: false
    t.datetime "created_at", null: false
    t.datetime "read_at"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
    t.index ["user_id"], name: "index_messages_on_user_id"
  end

  create_table "payments", force: :cascade do |t|
    t.decimal "amount"
    t.bigint "booking_id", null: false
    t.datetime "created_at", null: false
    t.string "currency"
    t.integer "status"
    t.string "stripe_payment_intent_id"
    t.datetime "updated_at", null: false
    t.index ["booking_id"], name: "index_payments_on_booking_id"
  end

  create_table "properties", force: :cascade do |t|
    t.string "address"
    t.integer "bathrooms"
    t.string "bed_configuration"
    t.integer "bedrooms"
    t.string "check_in_time", default: "3:00 PM"
    t.string "check_out_time", default: "10:30 AM"
    t.string "city"
    t.string "country"
    t.datetime "created_at", null: false
    t.text "description"
    t.boolean "has_desk", default: false
    t.boolean "has_meeting_room", default: false
    t.boolean "has_parking", default: false
    t.boolean "has_printer", default: false
    t.text "house_rules"
    t.boolean "instant_book", default: false
    t.float "latitude"
    t.float "longitude"
    t.integer "max_guests"
    t.text "nearby_attractions"
    t.decimal "price_per_night"
    t.string "property_type"
    t.integer "status", default: 0
    t.string "title"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "wifi_speed"
    t.index ["user_id"], name: "index_properties_on_user_id"
  end

  create_table "property_amenities", force: :cascade do |t|
    t.bigint "amenity_id", null: false
    t.datetime "created_at", null: false
    t.bigint "property_id", null: false
    t.datetime "updated_at", null: false
    t.index ["amenity_id"], name: "index_property_amenities_on_amenity_id"
    t.index ["property_id"], name: "index_property_amenities_on_property_id"
  end

  create_table "property_images", force: :cascade do |t|
    t.string "caption"
    t.datetime "created_at", null: false
    t.integer "position"
    t.bigint "property_id", null: false
    t.datetime "updated_at", null: false
    t.index ["property_id"], name: "index_property_images_on_property_id"
  end

  create_table "reviews", force: :cascade do |t|
    t.bigint "booking_id", null: false
    t.text "comment"
    t.datetime "created_at", null: false
    t.integer "rating", null: false
    t.bigint "reviewable_id", null: false
    t.string "reviewable_type", null: false
    t.bigint "reviewer_id", null: false
    t.datetime "updated_at", null: false
    t.index ["booking_id"], name: "index_reviews_on_booking_id"
    t.index ["reviewable_type", "reviewable_id"], name: "index_reviews_on_reviewable_type_and_reviewable_id"
    t.index ["reviewer_id"], name: "index_reviews_on_reviewer_id"
  end

  create_table "users", force: :cascade do |t|
    t.text "bio"
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "phone"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "role"
    t.string "stripe_account_id"
    t.string "stripe_customer_id"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "availabilities", "properties"
  add_foreign_key "bookings", "properties"
  add_foreign_key "bookings", "users"
  add_foreign_key "conversations", "properties"
  add_foreign_key "conversations", "users", column: "participant_1_id"
  add_foreign_key "conversations", "users", column: "participant_2_id"
  add_foreign_key "favorites", "properties"
  add_foreign_key "favorites", "users"
  add_foreign_key "messages", "conversations"
  add_foreign_key "messages", "users"
  add_foreign_key "payments", "bookings"
  add_foreign_key "properties", "users"
  add_foreign_key "property_amenities", "amenities"
  add_foreign_key "property_amenities", "properties"
  add_foreign_key "property_images", "properties"
  add_foreign_key "reviews", "bookings"
  add_foreign_key "reviews", "users", column: "reviewer_id"
end
