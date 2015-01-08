class ShippedParser
  def self.parse(mail, data)
    parse_html(mail, data)
    parse_text(mail, data)
    data.status == :parsed ? data : false
  end

  def self.parse_html(mail, data)
    return false if data.status == :parsed
    return false if !mail.from.join(" ")[/ebay\@ebay.com/]
    return false unless mail.subject[/^SHIPPED: /] || mail.subject[/^Updates for your purchase from/]

    html_part = mail.parts.find { |m| m.content_type[/^text\/html/] }
    return false if !html_part
    doc = Nokogiri::HTML(html_part.decode_body)

    items = {}
    product_blocks = doc.search('td.single-product-block')
    item_id_key = "itemId"
    if product_blocks.blank?
#      product_blocks = doc.search('tr td[colspan="2"] > a')
      product_blocks = doc.search('table[width="594"] tr td[width="594"] table[border="0"]')
#      pp product_blocks.count
      item_id_key = "item"
      if product_blocks.blank?
        product_blocks = doc.search('div#itemDetailsNewComponent table table[border="0"] td[width="445"] table[border="0"]')
        item_id_key = :type4
      end
    end
    return false if product_blocks.blank?

    product_blocks.each do |product|
      if item_id_key == :type4
        tracking_id = nil
        link = product.search('tr[height="45"] td a').first
        item_id_key = "iid"
        ebay_url = URI.parse(link.attr('href'))
        params = CGI.parse(ebay_url.query)
        next if !params["loc"]
        ebay_url = URI.parse(params["loc"].first)
        params = CGI.parse(ebay_url.query)
        if params[item_id_key].blank?
          item_id_key = "itemid"
        end
        next if params[item_id_key].blank?
        items[params[item_id_key].first] = {
          shipped_at: mail.date
        }
        line = product.search('tr[height="45"] td').last
        if line.children[0].text.strip[/^Tracking/]
          link = line.search('a')
          tracking_id = link.text
        end 
        items[params[item_id_key].first][:tracking_id] = tracking_id if !tracking_id.blank?
      else
        link = product.search('td.single-product-cta td.secondary-cta-button a')
        tracking_link = product.search('td.product-price a')
        if link.blank?
          link = product.search('tr td[colspan="2"] > a')
          tracking_link = product.search('td[colspan="9"] table tr td span + span > a')
        end
        ebay_url = URI.parse(link.attr('href'))
        params = CGI.parse(ebay_url.query)
        next if !params["loc"]
        ebay_url = URI.parse(params["loc"].first)
        params = CGI.parse(ebay_url.query)
        next if !params[item_id_key]
        items[params[item_id_key].first] = {
          shipped_at: mail.date
        }
        items[params[item_id_key].first][:tracking_id] = tracking_link.text.strip if !tracking_link.blank?
      end
    end

    data.items.merge!(items)
    
    data.status = :parsed
    data
  end

  def self.parse_text(mail, data)
    return false if data.status == :parsed
    return false if !mail.from.join(" ")[/ebay\@ebay.com/]
    return false unless mail.subject[/Updates for your purchase from/]
#    html_part = mail.parts.find { |m| m.content_type[/^text\/html/] }
#    return false if html_part
    
    plain_part = mail.parts.find { |m| m.content_type[/^text\/plain/] }
    mail_text = plain_part.nil? ? mail.decode_body : plain_part.decode_body

    items = {}

    mail_text.scan(/Item [Nn]ame:?\s+(.*?)\nItem URL:\s+(.*?)\n.*(for more information.\s+\nTracking number:\s+(.*)\nTracking URL|)/m).each do |link| 
      pp link
      url = link[1]
      tracking_number = link[3]
      ebay_url = URI.parse(url)
      params = CGI.parse(ebay_url.query)
      if params["item"].blank?
        ebay_url = URI.parse(params["loc"].first)
        params = CGI.parse(ebay_url.query)
      end
      
      items[params["item"].first] = {
        shipped_at: mail.date
      }
      items[params["item"].first][:tracking_id] = tracking_number.strip if !tracking_number.blank?
    end

    data.items.merge!(items)
    data.status = :parsed
    data
  end
end
