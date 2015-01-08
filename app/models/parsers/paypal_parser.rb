# -*- coding: utf-8 -*-
class PaypalParser
  def self.parse(mail, data)
    parse_paypal(mail, data)
    data.status == :parsed ? data : false
  end

  def self.is_paypal_address?(mail)
    return true if mail.from.join(" ")[/service\@paypal\.se/]
    return true if mail.from.join(" ")[/service\@paypal\.com/]
    return true if mail.from.join(" ")[/service\@intl\.paypal\.com/]
    false
  end
  
  def self.parse_paypal(mail, data)
    return false if data.status == :parsed
    return false if !is_paypal_address?(mail)
    html_part = mail.parts.find { |m| m.content_type[/^text\/html/] }
    return false if !html_part
    body = html_part.decode_body
    if html_part.charset == "windows-1252"
      body = body.force_encoding("windows-1252").encode("utf-8")
    end
    doc = Nokogiri::HTML(body)

    # Find item id
    ebay_link = doc.search("//a[contains(@href, 'cgi.ebay')]")
    if ebay_link.blank?
      ebay_link = doc.search("//a[contains(@href, 'cafr.ebay.ca')]")
    end
    if ebay_link.blank? || ebay_link.map { |x| x.attr('href') }.blank?
      data.status = :discarded
      return false
    end
    items = {}
    ebay_link.each do |link| 
      ebay_url = URI.parse(link.attr('href'))
    
      params = CGI.parse(ebay_url.query)
      params["item"] = params["Item"] if params["item"].blank?
      next if params["item"].blank?

      quantity_element = link.search("../following-sibling::td/following-sibling::td").first
      if quantity_element.blank?
        puts "ERROR: Quantity missing"
        return false 
      end

      cost_element = link.search("../following-sibling::td/following-sibling::td/following-sibling::td").first
      cost = 0
      cost_currency = nil
      if cost_element.text[/^[\$\€\£]?([\d\., ]+) ([A-Z]+)/]
        cost = $1
        cost_currency = $2
        cost = cost.tr(', ','._').to_f
      else
        puts "ERROR: Subcost not matching pattern: #{cost_element.text}"
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
    total_cost = 0
    if cost_element.blank?
      cost_element = doc.search("//td[contains(text(), 'Från belopp')]/following-sibling::td").first
    end
    if !cost_element.blank?
      if cost_element.text[/^([\d\., ]+) SEK/]
        total_cost = $1
        total_cost = total_cost.tr(', ','._').to_f
      else
        puts "ERROR: Cost not matching pattern: #{cost_element.text}"
        return false
      end
    else
      cost_element = doc.search("//td/span[contains(text(), 'Payment')]/../following-sibling::td").first
      pp mail.message_id
      if cost_element.text[/^[\$\€\£]?([\d, ]+) ([A-Z]+)/]
        cost = $1
        cost_currency = $2
        cost = cost.tr(', ','._').to_f
      end
      pp [cost, cost_currency]
      currency_conversion = {"USD" => 7}
      if currency_conversion[cost_currency]
        total_cost = currency_conversion[cost_currency] * cost
      else
        pp mail.subject
        puts "Unknown currency: #{cost_currency}"
        raise UnknownCurrency
      end
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
end
