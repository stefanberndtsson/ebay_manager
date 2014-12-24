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

  def self.fetch_unparsed_mails
    cnt = 0
    emails_in_label(LABEL_UNPARSED).each do |mail|
      parse_mail(mail)
      cnt += 1
      return if cnt > 150
    end
  end

  def self.download_all_unparsed_mails
    emails_in_label(LABEL_UNPARSED).each do |mail| 
      decomposed = Unicode.nfkd(mail.subject).gsub(/[^\u0000-\u00ff]/, "")
      puts "#{mail.uid}: #{decomposed}"
      File.open("/var/tmp/ebay-mails/#{mail.message_id}", "wb") do |file| 
        file.write(mail.raw_source)
      end
    end
  end

  def self.parse_mail(mail)
    EbayMail.parse_raw_mail(mail)
  end
end
