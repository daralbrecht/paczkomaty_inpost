require "net/https"
require "uri"

module PaczkomatyInpost

  class InpostRequest

    attr_accessor :username, :password, :params

    def initialize(username, password)
      self.username = username
      self.password = password
      self.params = {}
    end


    def inpost_get_params
      uri = URI.parse("#{INPOST_API_URL}/?do=getparams")
      response = Net::HTTP.get_response(uri)
      xml_doc = Nokogiri::XML(response.body)
      xml_doc.xpath('./paczkomaty/*').each do |param|
        params[param.name.to_sym] = param.text
      end
      params[:current_api_version] = PaczkomatyInpost::VERSION

      return params
    end

  end

end
