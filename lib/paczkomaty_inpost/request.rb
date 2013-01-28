# encoding: UTF-8
require "net/https"
require "uri"
require "csv"

module PaczkomatyInpost

  class Request

    attr_accessor :username, :password


    def initialize(username, password)
      self.username = username
      self.password = password
    end

    def inpost_get_params
      params = {}
      uri = URI.parse("#{PaczkomatyInpost.inpost_api_url}/?do=getparams")
      response = Net::HTTP.get_response(uri)
      xml_doc = Nokogiri::XML(response.body)
      xml_doc.xpath('./paczkomaty/*').each do |param|
        params[param.name.to_sym] = param.text
      end
      params[:current_api_version] = PaczkomatyInpost::VERSION

      return params
    end

    def inpost_download_machines
      uri = URI.parse("#{PaczkomatyInpost.inpost_api_url}/?do=listmachines_csv")
      response = Net::HTTP.get_response(uri)
      csv_content = response.body.gsub('"',"'").force_encoding('UTF-8')
      csv = CSV.parse(csv_content, :row_sep => :auto, :col_sep => ";")
      # TODO: Add checksum test
      unless csv.empty?
        machines = []
        csv.shift # removing checksum from array
        csv.each do |item|
          machine = {
            :name => item[0],
            :street => item[1],
            :buildingnumber => item[2],
            :postcode => item[3],
            :town => item[4],
            :latitude => item[5],
            :longitude => item[6],
            :paymentavailable => item[7] == 't' ? true : false,
            :operatinghours => item[8],
            :locationdescription => item[9],
            :paymentpointdescr => item[10],
            :partnerid => item[11].to_i,
            :paymenttype => item[12].to_i,
            :type => item[13]
          }
          machines << machine
        end

        return machines
      end
    end

  end
end
