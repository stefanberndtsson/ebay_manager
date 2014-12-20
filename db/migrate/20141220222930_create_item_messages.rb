class CreateItemMessages < ActiveRecord::Migration
  def change
    create_table :item_messages do |t|
      t.integer :item_id
      t.integer :ebay_message_id

      t.timestamps
    end
  end
end
