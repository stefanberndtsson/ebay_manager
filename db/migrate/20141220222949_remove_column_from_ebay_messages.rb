class RemoveColumnFromEbayMessages < ActiveRecord::Migration
  def change
    remove_column :ebay_messages, :item_id
  end
end
