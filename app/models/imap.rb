class Imap < ActiveRecord::Base
  class << self
    def connection
      @@gmail ||= nil
      return @@gmail if @@gmail && @@gmail.logged_in?
      
      @@gmail = Gmail.new(Rails.application.secrets.google_email, Rails.application.secrets.google_password)
      @@gmail
    end
  end
end
