class RenameMessageTables < ActiveRecord::Migration
  def change
    rename_table :ebay_messages, :ebay_mails
    rename_table :item_messages, :item_mails
  end
end
