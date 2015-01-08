# -*- coding: utf-8 -*-
class EbayMail < ActiveRecord::Base
  has_many :item_mails
  has_many :items, :through => :item_mails

  def self.parse_mail(mail)
    data = EbayMailData.new(message_id: mail.message_id)
    PaypalParser.parse(mail, data)
    OrderParser.parse(mail, data)
    ShippedParser.parse(mail, data)

    if data.status == :parsed && data.items.blank?
      data.status = :unparsable
    end

    if data.status == :parsed && data.items.keys.include?(nil)
      pp data
      pp mail.subject
      raise EbayIDMissing
    end

    if data.status != :parsed && DiscardParser.parse(mail, data)
      data.status = :discarded
    end

    if data.status != :parsed && data.status != :discarded
      data.subject = mail.subject
      pp data
      raise Unparsable
      data.status = :unparsable
    end

    create_or_update_item(data) if data.status == :parsed
    data.status
  end

  def self.create_or_update_item(data)
    items = data.items
    items.keys.each do |item_id|
      item = Item.where(ebay_id: item_id).where("delivered_at IS NULL").first
      if !item
        item = Item.create(items[item_id].merge({ebay_id: item_id}))
      else
        items[item_id].delete_if { |k,v| v.nil? }
        item.update_attributes(items[item_id])
      end
    end
  end
end
