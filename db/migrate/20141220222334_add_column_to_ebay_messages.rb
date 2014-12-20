class AddColumnToEbayMessages < ActiveRecord::Migration
  def change
    add_column :ebay_messages, :message_id, :text
  end
end
