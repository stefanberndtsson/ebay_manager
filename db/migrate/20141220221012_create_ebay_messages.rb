class CreateEbayMessages < ActiveRecord::Migration
  def change
    create_table :ebay_messages do |t|
      t.integer :item_id
      t.text :subject
      t.text :from
      t.text :to
      t.timestamp :received_at
      t.text :headers
      t.text :body

      t.timestamps
    end
  end
end
