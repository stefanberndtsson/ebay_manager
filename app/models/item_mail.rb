class ItemMail < ActiveRecord::Base
  belongs_to :item
  belongs_to :ebay_mail
end
