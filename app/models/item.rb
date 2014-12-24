class Item < ActiveRecord::Base
  has_many :item_mails
  has_many :ebay_mails, :through => :item_mails
end
