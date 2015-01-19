# -*- coding: utf-8 -*-
class EbayMail < ActiveRecord::Base
  has_many :item_mails
  has_many :items, :through => :item_mails

  def add_label(label)
    # TODO: Add label for current message_id
  end

  def remove_label(label)
    # TODO: Remove label for current message_id
  end

  def self.parse_mail(mail)
    begin
      data = EbayMailData.new
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
        pp mail.message_id
        pp mail.subject
        pp data
        File.open("/tmp/error.log", "a") do |file| 
          file.puts [mail.message_id, mail.subject].inspect
        end
#        raise Unparsable
        data.status = :unparsable
      end
    rescue
      mail.parts.each.with_index do |part,i| 
        ext = "txt"
        ext = "html" if part.content_type[/html/]
        File.open("/tmp/debug-error-#{i}.#{ext}", "wb") { |f| f.write(part.body) }
      end
      raise
    end
    if data.status == :parsed
      add_delivery_dates(mail, data)
      create_or_update_item(mail, data) 
    end
    data.status
  end

  def self.delivery_dates
    @@delivery_dates ||= {}
    return @@delivery_dates if !@@delivery_dates.blank?

    File.open("#{Rails.application.secrets.local_data_dir}/../delivery_dates.json", "rb") do |file| 
      @@delivery_dates = JSON.parse(file.read)
    end

    @@delivery_dates
  end

  def self.add_delivery_dates(mail, data)
    return if Rails.env != "development"
    if delivery_dates[mail.message_id]
      data.items.keys.each do |ebay_id|
        data.items[ebay_id][:delivered_at] = Time.parse(delivery_dates[mail.message_id])
      end
    end
  end

  def self.create_or_update_item(mail, data)
    items = data.items
    items.keys.each do |item_id|
      item = Item.find_by_ebay_id(item_id)
      if !item
        item = Item.create(items[item_id].merge({ebay_id: item_id}))
      else
        items[item_id].delete_if { |k,v| v.nil? }
        item.update_attributes(items[item_id])
      end
      ebay_mail = create_ebay_mail(mail)
      ebay_mail_link = item.item_mails.where(ebay_mail_id: ebay_mail.id)
      if ebay_mail_link.blank?
        item.item_mails.create(ebay_mail_id: ebay_mail.id)
      end
    end
  end

  def self.create_ebay_mail(mail)
    ebay_mail = EbayMail.find_by_message_id(mail.message_id)
    return ebay_mail if ebay_mail

    header_array = mail.header_fields.map do |x| 
      [x.name, x.value]
    end

    headers = Hash[header_array]

    EbayMail.create({
      subject: mail.subject,
      from: mail.from.join(" "),
      to: mail.to.join(" "),
      received_at: mail.date,
      headers: headers.to_json,
      body: mail.body.to_s,
      message_id: mail.message_id,
      raw: mail.to_s
    })
  end
end
