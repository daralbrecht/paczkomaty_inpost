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

      csv_content = get_response("/?do=listmachines_csv")

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

      xml_content = get_response("/?do=findnearestmachines&postcode=#{postcode}#{payment_available}")
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

    def inpost_download_pricelist
      pricelist = {}

      xml_content = get_response("/?do=pricelist")
      xml = Nokogiri::XML(xml_content)

      pricelist['on_delivery_payment'] = xml.css('on_delivery_payment').text unless xml.css('on_delivery_payment').text.nil?
      pricelist['on_delivery_percentage'] = xml.css('on_delivery_percentage').text unless xml.css('on_delivery_percentage').text.nil?
      pricelist['on_delivery_limit'] = xml.css('on_delivery_limit').text unless xml.css('on_delivery_limit').text.nil?

      xml_packtypes = xml.css('packtype')
      unless xml_packtypes.empty?
        xml_packtypes.each do |item|
          pricelist[item.css('type').text] = item.css('price').text
        end
      end

      xml_insurances = xml.css('insurance')
      unless xml_insurances.empty?
        insurances = {}
        xml_insurances.each do |item|
          insurances[item.css('limit').text] = item.css('price').text
        end
        pricelist['insurance'] = insurances unless insurances.empty?
      end

      return pricelist
    end


    private

    def get_response(params)
      uri = URI.parse("#{PaczkomatyInpost.inpost_api_url}#{params}")
      response = Net::HTTP.get_response(uri)
      return response.body.gsub('"',"'").to_my_utf8
    end
  end
end
