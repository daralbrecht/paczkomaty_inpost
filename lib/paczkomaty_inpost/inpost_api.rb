require "net/https"
require "uri"

module PaczkomatyInpost

  class InpostAPI

    attr_accessor :params


    def initialize
      self.params = {}
    end


    def inpost_check_environment(verbose = false)
      valid_options = true
      errors = [] if verbose

      if PaczkomatyInpost.options[:data_path].nil? || !File.directory?(PaczkomatyInpost.options[:data_path])
        valid_options = false
        errors << 'Paczkomaty API: path to proper data directory must be set in PaczkomatyInpost.options' if verbose
      end

      if PaczkomatyInpost.options[:data_path].nil? || !File.writable?(PaczkomatyInpost.options[:data_path])
        valid_options = false
        errors << 'Paczkomaty API: data_path in PaczkomatyInpost.options must be writable!' if verbose
      end

      if PaczkomatyInpost.options[:username].nil?
        valid_options = false
        errors << 'Paczkomaty API: username must be set in PaczkomatyInpost.options' if verbose
      end

      if PaczkomatyInpost.options[:password].nil?
        valid_options = false
        errors << 'Paczkomaty API: password must be set in PaczkomatyInpost.options' if verbose
      end

      if verbose
        return valid_options, errors
      else
        return valid_options
      end
    end


    def inpost_get_params
      uri = URI.parse("#{PaczkomatyInpost.inpost_api_url}/?do=getparams")
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