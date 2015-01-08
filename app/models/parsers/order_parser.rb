class OrderParser
  def self.parse(mail, data)
    parse_html(mail, data)
    parse_text(mail, data)
    data.status == :parsed ? data : false
  end

  def self.parse_html(mail, data)
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
      pp link
      ebay_url = URI.parse(link.attr('href'))
      params = CGI.parse(ebay_url.query)
      next if !params["loc"]
      ebay_url = URI.parse(params["loc"].first)
      params = CGI.parse(ebay_url.query)
      next if !params[item_id_key]
      next if params[item_id_key].first == link.text.strip
      items[params[item_id_key].first] = {
        title: link.text.strip,
        ordered_at: mail.date
      }
    end
    data.items.merge!(items)
    
    data.status = :parsed
    data
  end

  def self.parse_text(mail, data)
    return false if data.status == :parsed
    return false if !mail.from.join(" ")[/ebay\@ebay.com/]
    return false unless mail.subject[/Confirmation of your [oO]rder/] || mail.subject[/^Thank you for purchasing/]
    html_part = mail.parts.find { |m| m.content_type[/^text\/html/] }
    return false if html_part
    plain_part = mail.parts.find { |m| m.content_type[/^text\/plain/] }
    mail_text = plain_part.nil? ? mail.decode_body : plain_part.decode_body

    items = {}

    mail_text.scan(/Item [nN]ame:?\s+(.*?)\nItem URL:\s+(.*?)\n/m).each do |link| 
      pp link
      title = link[0].gsub(/\n/m,'')
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
end
