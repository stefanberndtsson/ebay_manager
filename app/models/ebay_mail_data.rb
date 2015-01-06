class EbayMailData
  KEYS=[:subject, :items, :status, :message_id]

  def initialize(content = {})
    @data = content
    @data[:items] ||= {}
  end

  def method_missing(method, *args)
    KEYS.each do |key| 
      if method == key
        return @data[key]
      elsif method.to_s == "#{key.to_s}="
        @data[key] = args.first
        return
      end
    end
    super
  end
end
