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

ActiveRecord::Schema[8.1].define(version: 2026_04_22_104048) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "cached_queries", force: :cascade do |t|
    t.text "ai_response", null: false
    t.datetime "created_at", null: false
    t.integer "hit_count", default: 0
    t.integer "product_ids", default: [], array: true
    t.vector "query_embedding", limit: 384
    t.text "query_text", null: false
    t.datetime "updated_at", null: false
    t.index ["query_embedding"], name: "index_cached_queries_on_embedding", opclass: :vector_cosine_ops, using: :ivfflat
  end

  create_table "messages", force: :cascade do |t|
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.string "role", null: false
    t.string "session_id", null: false
    t.datetime "updated_at", null: false
    t.index ["session_id"], name: "index_messages_on_session_id"
  end

  create_table "products", force: :cascade do |t|
    t.string "brand"
    t.string "category"
    t.datetime "created_at", null: false
    t.text "description"
    t.vector "embedding", limit: 384
    t.string "name", null: false
    t.decimal "price", precision: 10, scale: 2
    t.jsonb "specifications", default: {}
    t.integer "stock", default: 0
    t.datetime "updated_at", null: false
    t.index ["embedding"], name: "index_products_on_embedding", opclass: :vector_cosine_ops, using: :ivfflat
  end
end
