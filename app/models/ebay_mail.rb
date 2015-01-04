# -*- coding: utf-8 -*-
class EbayMail < ActiveRecord::Base
  has_many :item_mails
  has_many :items, :through => :item_mails

  def self.parse_mail(mail)
    data = EbayMailData.new(message_id: mail.message_id)
    parse_paypal(mail, data)
    parse_order_html(mail, data)
    parse_order_text(mail, data)
    if data.status != :parsed
      data.subject = mail.subject
      data.status = :unparsable
    end

    create_or_update_item(data) if data.status == :parsed
  end

  def self.parse_paypal(mail, data)
    return false if data.status == :parsed
    return false if !mail.from.join(" ")[/service\@paypal\.se/]
    html_part = mail.parts.find { |m| m.content_type[/^text\/html/] }
    return false if !html_part
    doc = Nokogiri::HTML(html_part.decode_body)

    # Find item id
    ebay_link = doc.search("//a[contains(@href, 'ebay.com')]")
    return false if ebay_link.blank?
    return false if ebay_link.map { |x| x.attr('href') }.blank?
    items = {}
    ebay_link.each do |link| 
      ebay_url = URI.parse(link.attr('href'))
      params = CGI.parse(ebay_url.query)
      next if params["item"].blank?

      quantity_element = link.search("../following-sibling::td/following-sibling::td").first
      if quantity_element.blank?
        puts "ERROR: Quantity missing"
        return false 
      end

      cost_element = link.search("../following-sibling::td/following-sibling::td/following-sibling::td").first
      cost = 0
      cost_currency = nil
      if cost_element.text[/^[\$\€]?([\d, ]+) ([A-Z]+)/]
        cost = $1
        cost_currency = $2
        cost = cost.tr(', ','._').to_f
      else
        puts "ERROR: Cost not matching pattern: #{cost_element.text}"
        return false
      end

      title = link.text.strip
      quantity = quantity_element.text.to_i
      quantity *= title_quantity(title)

      items[params["item"].first] = { 
        title: title,
        quantity: quantity,
        tmp_cost: cost,
        tmp_cost_currency: cost_currency,
        payment_at: mail.date
      }
    end
    return false if items.keys.blank?
    data.items.merge!(items)
    
    # Find cost
    cost_element = doc.search("//td[contains(text(), 'From amount')]/following-sibling::td").first
    return false if cost_element.blank?
    total_cost = 0
    if cost_element.text[/^([\d, ]+) SEK/]
      total_cost = $1
      total_cost = total_cost.tr(', ','._').to_f
    else
      puts "ERROR: Cost not matching pattern: #{cost_element.text}"
      return false
    end
    
    currencies = data.items.map { |k,v| data.items[k][:tmp_cost_currency] }.uniq
    return false if currencies.size != 1
    
    total_sub_cost = data.items.map { |k,v| data.items[k][:tmp_cost] }.inject(&:+)
    
    data.items.map do |k,v|
      data.items[k][:cost] = total_cost * data.items[k][:tmp_cost]/total_sub_cost
      data.items[k].delete(:tmp_cost)
      data.items[k].delete(:tmp_cost_currency)
    end

    data.status = :parsed
    data
  end

  def self.title_quantity(title)
    if title[/\b(\d+) ?pcs?\b/i]
      return $1.to_i
    end
    return 1
  end

  def self.parse_order_html(mail, data)
    return false if data.status == :parsed
    return false if !mail.from.join(" ")[/ebay\@ebay.com/]
    return false unless mail.subject[/^ORDER: /] || mail.subject[/Confirmation of your order/]

    html_part = mail.parts.find { |m| m.content_type[/^text\/html/] }
    return false if !html_part
    doc = Nokogiri::HTML(html_part.decode_body)

    # File.open("/tmp/order2.html", "wb") { |f| f.puts doc } 

    items = {}
    ebay_link = doc.search('h2.product-name a')
    item_id_key = "itemId"
    if ebay_link.blank?
      ebay_link = doc.search('tr td[colspan="2"] > a')
      item_id_key = "item"
    end
    return false if ebay_link.blank?

    ebay_link.each do |link|
      ebay_url = URI.parse(link.attr('href'))
      params = CGI.parse(ebay_url.query)
      return false if !params["loc"]
      ebay_url = URI.parse(params["loc"].first)
      params = CGI.parse(ebay_url.query)
      return false if !params[item_id_key]
      items[params[item_id_key].first] = {
        title: link.text.strip,
        ordered_at: mail.date
      }
    end
    data.items.merge!(items)
    
    data.status = :parsed
    data
  end

  def self.parse_order_text(mail, data)
    return false if data.status == :parsed
    return false if !mail.from.join(" ")[/ebay\@ebay.com/]
    return false unless mail.subject[/Confirmation of your order/]
    html_part = mail.parts.find { |m| m.content_type[/^text\/html/] }
    return false if html_part
    
    plain_part = mail.parts.find { |m| m.content_type[/^text\/plain/] }
    mail_text = plain_part.decode_body

    items = {}

    mail_text.scan(/Item name\s+(.*)\nItem URL:\s+(.*)/).each do |link| 
      title = link[0]
      url = link[1]
      ebay_url = URI.parse(url)
      params = CGI.parse(ebay_url.query)
      ebay_url = URI.parse(params["loc"].first)
      params = CGI.parse(ebay_url.query)
      
      items[params["item"].first] = {
        title: title,
        ordered_at: mail.date
      }
    end

    data.items.merge!(items)
    data.status = :parsed
    data
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
