class EbayMail < ActiveRecord::Base
  has_many :item_mails
  has_many :items, :through => :item_mails

  def self.parse_raw_mail(mail)
    msg = EbayMail.find_by_message_id(mail.message_id)
    items = extract_items(mail)
    item_ids = items.map(&:id)
    if msg
      msg_item_ids = msg.item_mail_ids
      return if (item_ids&msg_item_ids).present?  # Already parsed and connected this mail to the item
    end
    if items.blank?
      mail.move_to(Imap::LABEL_UNKNOWN)
      return
    end
    parse_mail(items, mail.mail_id, mail.subject,
                  mail.from, mail.to,
                  mail.header_fields, mail.body,
                  mail.raw_source, msg)
    mail.move_to(Imap::LABEL_PARSED)
  end

  def self.extract_items(mail)
    plains = plain_text_part(mail)
    items = []
    if !plains.blank?
      plains.each do |plain| 
        plain.body.to_s.gsub(/Item (Id|# ): (\d+)/m) do |x|
          items << add_item($2)
        end
        next if !items.blank?
      end
    else
      pp ["other-types", mail.parts.map(&:content_type)]
    end
    items
  end

  def self.add_item(item_id)
    item = Item.find_by_ebay_id(item_id)
    if !item
      item = Item.create(ebay_id: item_id)
    end
    item
  end

  def self.plain_text_part(mail)
    mail.parts.select { |x| x.content_type[/^text\/plain/] }
  end

  def self.parse_mail(items, mail_id, subject, from, to, headers, body, raw, msg = nil)
    items.each do |item|
      if !msg
        msg = Eailsage.create(subject: subject, from: from.to_json, to: to.to_json, mail_id: mail_id, 
                                 headers: headers.to_json, body: body.to_json, raw: raw)
      end
      item.item_mails.create(ebay_mail_id: msg.id)
    end
  end
end
