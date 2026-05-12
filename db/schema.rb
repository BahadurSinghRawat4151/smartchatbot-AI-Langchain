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

ActiveRecord::Schema[8.1].define(version: 2026_05_05_053213) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "messages", force: :cascade do |t|
    t.text "ai_summary"
    t.bigint "user_id"
    t.index ["user_id"], name: "index_messages_on_user_id"
  end

  create_table "policies", force: :cascade do |t|
    t.string "category"
    t.datetime "created_at", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["title"], name: "index_policies_on_title"
  end

  create_table "policy_chunks", force: :cascade do |t|
    t.integer "chunk_index"
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.vector "embedding", limit: 384
    t.bigint "policy_id", null: false
    t.datetime "updated_at", null: false
    t.index ["policy_id"], name: "index_policy_chunks_on_policy_id"
  end

  create_table "products", force: :cascade do |t|
    t.string "brand"
    t.string "category"
    t.datetime "created_at", null: false
    t.text "description"
    t.vector "embedding", limit: 384
    t.text "images"
    t.string "name", null: false
    t.decimal "price", precision: 10, scale: 2
    t.string "product_type"
    t.jsonb "specifications", default: {}
    t.integer "stock", default: 0
    t.jsonb "tags", default: []
    t.datetime "updated_at", null: false
    t.index ["embedding"], name: "index_products_on_embedding", opclass: :vector_cosine_ops, using: :ivfflat
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "messages", "users"
  add_foreign_key "policy_chunks", "policies"
end
