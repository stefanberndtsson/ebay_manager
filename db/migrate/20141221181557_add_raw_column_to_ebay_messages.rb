class AddRawColumnToEbayMessages < ActiveRecord::Migration
  def change
    add_column :ebay_messages, :raw, :text
  end
end
