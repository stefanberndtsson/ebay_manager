class Gmail
  def raw_imap
    @imap
  end
end

class Imap
  LABEL_UNPARSED="EbayManager/Unparsed"
  LABEL_PARSED="EbayManager/Parsed"
  LABEL_UNKNOWN="EbayManager/Unknown"

  class << self
    def connection
      @@gmail ||= nil
      return @@gmail if @@gmail && @@gmail.logged_in? && !@@gmail.raw_imap.disconnected?
      
      puts "Connecting"
      @@gmail = Gmail.new(Rails.application.secrets.google_email, Rails.application.secrets.google_password)
      @@gmail
    end
  end

  def self.labels
    connection.labels
  end

  def self.in_label(label)
    connection.in_label(label)
  end

  def self.emails_in_label(label)
    connection.in_label(label).emails
  end

  def self.fetch_unparsed_messages
    emails_in_label(LABEL_UNPARSED).each do |message|
      parse_message(message)
      return
    end
  end

  def self.parse_message(message)
    EbayMessage.parse_raw_message(message)
  end
end
