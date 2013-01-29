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
      machines = []
      uri = URI.parse("#{PaczkomatyInpost.inpost_api_url}/?do=listmachines_csv")
      response = Net::HTTP.get_response(uri)
      csv_content = response.body.gsub('"',"'").to_my_utf8
      csv = CSV.parse(csv_content, :row_sep => :auto, :col_sep => ";")
      # TODO: Add checksum test
      unless csv.empty?
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

    def inpost_download_nearest_machines(postcode,paymentavailable=nil)
      machines = []
      payment_available = ''
      unless paymentavailable.nil?
        payment_available = "&paymentavailable=#{paymentavailable ? 't' : 'f'}"
      end

      uri = URI.parse("#{PaczkomatyInpost.inpost_api_url}/?do=findnearestmachines&postcode=#{postcode}#{payment_available}")
      response = Net::HTTP.get_response(uri)
      xml_content = response.body.gsub('"',"'").to_my_utf8
      xml = Nokogiri::XML(xml_content)
      xml_machines = xml.css('machine')
      unless xml_machines.empty?
        xml_machines.each do |item|
          machine = {
            :name => item.css('name').text,
            :postcode => item.css('postcode').text,
            :street => item.css('street').text,
            :buildingnumber => item.css('buildingnumber').text,
            :town => item.css('town').text,
            :latitude => item.css('latitude').text,
            :longitude => item.css('longitude').text,
            :distance => item.css('distance').text
          }
          machines << machine
        end
      end

      return machines
    end

  end
end
