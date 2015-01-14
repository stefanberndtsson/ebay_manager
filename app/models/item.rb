class Item < ActiveRecord::Base
  has_many :item_mails
  has_many :ebay_mails, :through => :item_mails

  def self.set_dates_from_known_date
    Item.where("payment_at IS NOT NULL").where(ordered_at: nil).each do |item| 
      item.update_attribute(:ordered_at, item.payment_at)
    end
    Item.where("ordered_at IS NOT NULL").where(payment_at: nil).each do |item| 
      item.update_attribute(:payment_at, item.ordered_at)
    end
    Item.where(delivered_at: nil).each do |item|
      if item.shipped_at
        item.update_attribute(:delivered_at, item.shipped_at + 3.weeks)
      else
        item.update_attribute(:delivered_at, item.ordered_at + 4.weeks)
      end
    end
  end

  def delivered_label_name(timestamp)
    timestamp.strftime("Z/Delivered/%Y-%m-%d")
  end

  def mark_as_delivered
    timestamp = Time.now
    update_attribute(:delivered_at, timestamp)
    set_label_for_all_mails(delivered_label_name(timestamp))
  end

  def set_label_for_all_mails(label)
    ebay_mails.each do |ebay_mail| 
      ebay_mail.set_label(label)
    end
  end

  def remove_label_for_all_mails(label)
    ebay_mails.each do |ebay_mail| 
      ebay_mail.remove_label(label)
    end
  end
end
