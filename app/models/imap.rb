class Gmail
  def raw_imap
    @imap
  end
end

class Mail::Message
  def move_to(label)
    Imap.set_label(label, self)
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

  def self.set_label(label, message)
    if Rails.env == 'production'
      msg = gmail_message_by_msgid(message.message_id)
      if msg
        msg.label(label)
      end
    else
      puts "Would have set label: #{label}"
    end
  end
  
  def self.gmail_message_by_msgid(msgid, label = LABEL_UNPARSED)
    in_label(label).emails(:all, {gm: 'rfc822msgid:'+msgid}).first
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

  def self.load_mail_from_file(filename)
    File.open(filename, "rb") do |mail|
      return Mail.new(mail.read)
    end
  end

  def self.fetch_unparsed_mails(maxcnt = nil, return_unparsed = false)
    if Rails.env == "development"
      cnt = 0
      mails = [] if return_unparsed
      result = []
      Dir.open("#{Rails.application.secrets.local_data_dir}").each do |file|
        next unless File.file?("#{Rails.application.secrets.local_data_dir}/#{file}")
        break if maxcnt && cnt >= maxcnt
        mail_message = load_mail_from_file("#{Rails.application.secrets.local_data_dir}/#{file}")
        if return_unparsed
          mails << mail_message 
        else
          result << EbayMail.parse_mail(mail_message)
        end
        cnt += 1
      end
      return mails if return_unparsed
      return result
    else
      cnt = 0
      emails_in_label(LABEL_UNPARSED).each do |mail|
        parse_mail(mail)
        cnt += 1
        return if cnt > 150
      end
    end
  end

  def self.download_all_unparsed_mails
    emails_in_label(LABEL_UNPARSED).each do |mail| 
      decomposed = Unicode.nfkd(mail.subject).gsub(/[^\u0000-\u00ff]/, "")
      puts "#{mail.uid}: #{decomposed}"
      File.open("#{Rails.application.secrets.local_data_dir}/#{mail.message_id}", "wb") do |file| 
        file.write(mail.raw_source)
      end
    end
  end
end
