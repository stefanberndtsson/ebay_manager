class EbayMail < ActiveRecord::Base
  has_many :item_mails
  has_many :items, :through => :item_mails

  def self.parse_mail(mail)
    data = {}
    if parse_paypal(mail, data)
      puts "Parsed data:"
      pp data
    else
      pp mail.from.join(" ")
      puts "DEBUG: No parser yet..."
    end
  end

  def self.parse_paypal(mail, data)
    return false if !mail.from.join(" ")[/service\@paypal\.se/]
    html_part = mail.parts.find { |m| m.content_type[/^text\/html/] }
    return false if !html_part
    doc = Nokogiri::HTML(html_part.decode_body)

    # Find item id
    ebay_link = doc.search("//a[contains(@href, 'ebay.com')]")
    return false if ebay_link.blank?
    return false if ebay_link.attr('href').blank?
    ebay_url = URI.parse(ebay_link.attr('href'))
    params = CGI.parse(ebay_url.query)
    return false if params["item"].blank?
    data[:item] = params["item"]


    # Find quantity
    quantity_element = doc.search("//a[contains(@href, 'ebay.com')]/../following-sibling::td/following-sibling::td").first
    return false if quantity_element.blank?
    data[:quantity] = quantity_element.text


    # Find cost
    cost_element = doc.search("//td[contains(text(), 'From amount')]/following-sibling::td").first
    return false if cost_element.blank?
    if cost_element.text[/^([\d,]+) SEK/]
      cost = $1
      cost = cost.gsub(/,/,'.').to_f
      data[:cost] = cost
    else
      puts "ERROR: Cost not matching pattern: #{cost_element.text}"
      return false
    end

    data
  end

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

  def self.xparse_mail(items, mail_id, subject, from, to, headers, body, raw, msg = nil)
    items.each do |item|
      if !msg
        msg = EbayMail.create(subject: subject, from: from.to_json, to: to.to_json, mail_id: mail_id, 
                                 headers: headers.to_json, body: body.to_json, raw: raw)
      end
      item.item_mails.create(ebay_mail_id: msg.id)
    end
  end
end
