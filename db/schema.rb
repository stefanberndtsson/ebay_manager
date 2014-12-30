# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20141230224413) do

  create_table "ebay_mails", force: true do |t|
    t.text     "subject"
    t.text     "from"
    t.text     "to"
    t.datetime "received_at"
    t.text     "headers"
    t.text     "body"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "message_id"
    t.text     "raw"
  end

  create_table "item_mails", force: true do |t|
    t.integer  "item_id"
    t.integer  "ebay_message_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "items", force: true do |t|
    t.integer  "ebay_id"
    t.text     "title"
    t.integer  "state_id"
    t.float    "cost"
    t.datetime "delivered_at"
    t.datetime "shipped_at"
    t.text     "tracking_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "quantity"
    t.datetime "payment_at"
    t.datetime "ordered_at"
  end

end
