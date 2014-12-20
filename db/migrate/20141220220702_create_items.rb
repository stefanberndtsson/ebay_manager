class CreateItems < ActiveRecord::Migration
  def change
    create_table :items do |t|
      t.integer :ebay_id
      t.text :title
      t.integer :state_id
      t.float :cost
      t.timestamp :delivered_at
      t.timestamp :shipped_at
      t.text :tracking_id

      t.timestamps
    end
  end
end
