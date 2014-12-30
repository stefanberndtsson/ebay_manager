class AddThreeColumnsToItems < ActiveRecord::Migration
  def change
    add_column :items, :quantity, :integer
    add_column :items, :payment_at, :timestamp
    add_column :items, :ordered_at, :timestamp
  end
end
