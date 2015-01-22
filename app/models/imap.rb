class Gmail
  def raw_imap
    @imap
  end

  def devel_connect
    @imap.disconnect
    @imap = Net::IMAP.new('localhost', 143)
  end

  class Mailbox
    def imap_search_msgid(msgid)
      @gmail.in_mailbox(self) do
        @gmail.imap.uid_search("HEADER Message-ID #{msgid}").map do |uid|
          messages[uid] ||= Message.new(@gmail, self, uid)
        end
      end
    end
  end
end

#class Net::IMAP
#  alias_method :old_uid_search, :uid_search
#
#  def uid_search(*args)
#    pp ["DEBUG", args]
#    old_uid_search(*args)
#  end
#end

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
      @@gmail.devel_connect if Rails.env != "production"
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

  def self.imap_message_by_msgid(msgid, label = LABEL_UNPARSED)
    in_label(label).imap_search_msgid(msgid).first
  end

  def self.message_by_msgid(msgid, label = LABEL_UNPARSED)
    if Rails.env == 'production'
      return gmail_message_by_msgid(msgid, label)
    else
      return imap_message_by_msgid(msgid, label)
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

  def self.load_mail_from_file(filename)
    File.open(filename, "rb") do |mail|
      return Mail.new(mail.read)
    end
  end

  def self.fetch_unparsed_from_files(maxcnt = nil, return_unparsed = false)
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
    Item.set_dates_from_known_date
    return result
  end

  def self.fetch_unparsed_from_server(maxcnt = nil, return_unparsed = false)
    cnt = 0
    emails_in_label(LABEL_UNPARSED).each do |mail|
      pp mail
      EbayMail.parse_mail(mail)
      cnt += 1
      return if maxcnt && cnt > maxcnt
    end
    Item.set_dates_from_known_date
  end

  def self.fetch_unparsed_mails(maxcnt = nil, return_unparsed = false)
    if Rails.env == "development"
      fetch_unparsed_from_server(maxcnt, return_unparsed)
    else
      fetch_unparsed_from_server(maxcnt, return_unparsed)
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

  def self.download_delivered_labels
    message_deliveries = {}
    labels.each do |label| 
      next unless label[/Z\/Delivered\/\d+-\d+-\d+/]
      puts label
      date = label[/Z\/Delivered\/(\d+-\d+-\d+)/, 1]
      cnt = 0
      emails_in_label(label).each do |mail| 
        if message_deliveries[mail.message_id]
          puts "Duplicate delivery dates for #{mail.message_id}"
        end
        message_deliveries[mail.message_id] = date
        cnt += 1
      end
      puts "Message count: #{cnt}"
    end
    File.open("#{Rails.application.secrets.local_data_dir}/../delivery_dates.json", "wb") do |file| 
      file.write(message_deliveries.to_json)
    end
  end
end
