class EbayMessage < ActiveRecord::Base
  has_many :item_messages
  has_many :items, :through => :item_messages

  def self.parse_raw_message(message)
    msg = EbayMessage.find_by_message_id(message.message_id)
    items = extract_items(message)
    item_ids = items.map(&:id)
    if msg
      msg_item_ids = msg.item_message_ids
      return if (item_ids&msg_item_ids).present?  # Already parsed and connected this message to the item
    end
    if items.blank?
      message.move_to(Imap::LABEL_UNKNOWN)
      return
    end
    parse_message(items, message.message_id, message.subject,
                  message.from, message.to,
                  message.header_fields, message.body,
                  message.raw_source, msg)
    message.move_to(Imap::LABEL_PARSED)
  end

  def self.extract_items(message)
    plains = plain_text_part(message)
    items = []
    if !plains.blank?
      plains.each do |plain| 
        plain.body.to_s.gsub(/Item (Id|# ): (\d+)/m) do |x|
          items << add_item($2)
        end
        next if !items.blank?
      end
    else
      pp ["other-types", message.parts.map(&:content_type)]
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

  def self.plain_text_part(message)
    message.parts.select { |x| x.content_type[/^text\/plain/] }
  end

  def self.parse_message(items, message_id, subject, from, to, headers, body, raw, msg = nil)
    items.each do |item|
      if !msg
        msg = EbayMessage.create(subject: subject, from: from.to_json, to: to.to_json, message_id: message_id, 
                                 headers: headers.to_json, body: body.to_json, raw: raw)
      end
      item.item_messages.create(ebay_message_id: msg.id)
    end
  end
end
