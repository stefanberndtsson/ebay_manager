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
    parse_message(item_ids, message.message_id, message.subject,
                  message.from, message.to,
                  message.header_fields, message.body)
  end

  def self.extract_items(message)
    plains = plain_text_part(message)
    return [] if plains.blank?
    item_ids = []
    plains.each do |plain| 
      plain.body.to_s.gsub(/Item # : (\d+)/m) do |x|
        item_ids << $1
      end
    end
    pp item_ids
    []
  end

  def self.plain_text_part(message)
    message.parts.select { |x| x.content_type[/^text\/plain/] }
  end

  def self.parse_message(item_ids, message_id, subject, from, to, headers, body)
  end
end
