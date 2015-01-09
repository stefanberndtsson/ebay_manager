class RenameEbayMessageIdColumn < ActiveRecord::Migration
  def change
    rename_column :item_mails, :ebay_message_id, :ebay_mail_id
  end
end
