class ItemMessage < ActiveRecord::Base
  belongs_to :item
  belongs_to :ebay_message
end
