class Item < ActiveRecord::Base
  has_many :item_mails
  has_many :ebay_mails, :through => :item_mails

  def state
    if is_ordered? && !is_shipped?
      return "Ordered"
    elsif is_shipped? && !is_delivered?
      return "Shipped"
    elsif is_delivered?
      return "Delivered"
    else
      return "Unknown"
    end
  end

  # Technically this should always be true
  def is_ordered?
    !!ordered_at
  end

  def is_shipped?
    !!shipped_at
  end

  def is_delivered?
    !!delivered_at
  end

  def self.set_dates_from_known_date
    Item.where("payment_at IS NOT NULL").where(ordered_at: nil).each do |item| 
      item.update_attribute(:ordered_at, item.payment_at)
    end
    Item.where("ordered_at IS NOT NULL").where(payment_at: nil).each do |item| 
      item.update_attribute(:payment_at, item.ordered_at)
    end
  end

  def set_automatic_delivery_date
    if shipped_at
      update_attribute(:delivered_at, shipped_at + 3.weeks)
    else
      update_attribute(:delivered_at, ordered_at + 4.weeks)
    end
  end

  def mark_as_delivered(timestamp = Time.now)
    update_attribute(:delivered_at, timestamp)
  end
end
