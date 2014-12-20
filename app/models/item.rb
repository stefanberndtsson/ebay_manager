class Item < ActiveRecord::Base
  has_many :item_messages
  has_many :ebay_messages, :through => :item_messages
end
