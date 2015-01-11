class DiscardParser
  def self.parse(mail, data)
    discard_unwanted(mail)
  end
  
  def self.discard_unwanted(mail)
    return true if !PaypalParser.is_paypal_sender?(mail) && !mail.from.join(" ")[/ebay\@ebay.com/]
    return true if mail.subject[/^ENDING:/]
    return true if mail.subject[/^GOT AWAY:/]
    return true if mail.subject[/^GET READY:/]
    return true if mail.subject[/^ALMOST GONE:/]
    return true if mail.subject[/^YOU WON:/]
    return true if mail.subject[/^OUTBID:/]
    return true if mail.subject[/^Outbid notice:/]
    return true if mail.subject[/^Your eBay bid is confirmed :/]
    return true if mail.subject[/^Case # \d+ is now open/]
    return true if mail.subject[/^Case # \d+: /]
    return true if mail.subject[/^Your PayPal payment has been refunded/]
    return true if mail.subject[/^Canceling purchase for /]
    return true if mail.subject[/^Transaction has been cancelled:/]
    return true if mail.subject[/^Item ends soon:/]
    return true if mail.subject[/^Watch item ends soon:/]
    return true if mail.subject[/^Watch Alert: \d+ items end soon/]
    return true if mail.subject[/^An item you\'ve been watching has been relisted/]
    return true if mail.subject[/^Items you\'ve been watching have been relisted/]
    return true if mail.subject[/^Alert: \d+ items end soon/]
    return true if mail.subject[/^eBay Watched Items? Reminder:?/]
    return true if mail.subject[/^After \d+ days when we shipped the item/]
    return true if mail.subject[/^\d+ days Passed, /]
    return true if mail.subject[/^\d+days passed, check if you/]
    return true if mail.subject[/^New items that match: /]
    return true if mail.subject[/^Don\'t miss out on /]
    return true if mail.subject[/^Have you received /]
    return true if mail.subject[/^Other: (.*) sent a message about /]
    return true if mail.subject[/^Your item has been sent out/]
    return true if mail.subject[/^Please leave feedback for eBay item /]
    return true if mail.subject[/^Seller is requesting Feedback revision:/]
    return true if mail.subject[/^Your invoice for eBay purchases:/]
    return true if mail.subject[/^Goods delivery notification/]
    return true if mail.subject[/^Enjoy your /]
    return true if mail.subject[/^Sorry you didn\'t win /]
    return true if mail.subject[/^Welcome to eBay/]
    return true if mail.subject[/^eBay Change Password Confirmation/]
    return true if mail.subject[/^eBay User Information Request/]

    return true if mail.subject[/^You have authorized a payment to/]
    return true if mail.subject[/^Receipt for your donation/]
    false
  end
end
