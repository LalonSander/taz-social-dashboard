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

ActiveRecord::Schema[7.1].define(version: 2026_01_24_150855) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "post_metrics", force: :cascade do |t|
    t.bigint "post_id", null: false
    t.integer "likes", default: 0
    t.integer "replies", default: 0
    t.integer "reposts", default: 0
    t.integer "quotes", default: 0
    t.integer "total_interactions", default: 0
    t.datetime "recorded_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["post_id", "recorded_at"], name: "index_post_metrics_on_post_and_recorded_at"
    t.index ["post_id"], name: "index_post_metrics_on_post_id"
    t.index ["recorded_at"], name: "index_post_metrics_on_recorded_at"
  end

  create_table "posts", force: :cascade do |t|
    t.bigint "social_account_id", null: false
    t.bigint "article_id"
    t.string "platform", null: false
    t.string "platform_post_id", null: false
    t.text "content", null: false
    t.string "external_url"
    t.string "post_type", null: false
    t.datetime "posted_at", null: false
    t.jsonb "platform_data", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["article_id"], name: "index_posts_on_article_id"
    t.index ["external_url"], name: "index_posts_on_external_url"
    t.index ["platform", "platform_post_id"], name: "index_posts_on_platform_and_platform_post_id", unique: true
    t.index ["platform"], name: "index_posts_on_platform"
    t.index ["post_type"], name: "index_posts_on_post_type"
    t.index ["posted_at"], name: "index_posts_on_posted_at"
    t.index ["social_account_id"], name: "index_posts_on_social_account_id"
  end

  create_table "social_accounts", force: :cascade do |t|
    t.string "platform", null: false
    t.string "handle", null: false
    t.string "platform_id"
    t.text "access_token"
    t.datetime "last_synced_at"
    t.boolean "active", default: true
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_social_accounts_on_active"
    t.index ["platform", "handle"], name: "index_social_accounts_on_platform_and_handle", unique: true
    t.index ["platform"], name: "index_social_accounts_on_platform"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "post_metrics", "posts"
  add_foreign_key "posts", "social_accounts"
end
