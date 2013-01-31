# encoding: UTF-8
require "net/https"
require "uri"
require "csv"
require 'base64'
require 'digest/md5'
require 'builder'
require 'rack'

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

    def digest
      @digest ||= Base64.encode64(Digest::MD5.digest(password)).chomp
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

    def inpost_download_customer_preferences(email)
      preferences = {}

      xml_content = get_response("/?do=findcustomer&email=#{email}")
      xml = Nokogiri::XML(xml_content)

      xml_customer = xml.css('customer')
      if xml_customer.empty?
        preferences['error'] = {xml.css('error').attribute('key').value => xml.css('error').text}
      else
        preferences['preferedBoxMachineName'] = xml_customer.css('preferedBoxMachineName').text
        preferences['alternativeBoxMachineName'] = xml_customer.css('alternativeBoxMachineName').text
      end

      return preferences
    end

    def pack_status(packcode)
      pack_status = {}

      xml_content = get_response("/?do=getpackstatus&packcode=#{packcode}")
      xml = Nokogiri::XML(xml_content)

      xml_status = xml.css('status')
      if xml_status.empty?
        pack_status['error'] = {xml.css('error').attribute('key').value => xml.css('error').text}
      else
        pack_status['status'] = xml_status.css('status').text
      end

      return pack_status
    end

    def send_packs(packs_data, auto_labels=1, self_send=0)
      sended_packs = {}

      xml_packs_data = generate_xml_for_data_packs(packs_data, auto_labels, self_send)

      params = {:email => username, :digest => digest, :content => xml_packs_data.target!}
      data = http_build_query(params)

      xml_response = get_https_response(data,'/?do=createdeliverypacks')
      xml = Nokogiri::XML(xml_response)
      xml_packs = xml.css('pack')
      if xml_packs.empty?
        sended_packs['error'] = {xml.css('error').attribute('key').value => xml.css('error').text} unless xml.css('error').empty?
      else
        xml_packs.each do |pack|
          pack_info = {}
          pack_id = pack.css('id').text
          pack_info['packcode'] = pack.css('packcode').text unless pack.css('packcode').text.empty?
          pack_info['calculatedcharge'] = pack.css('calculatedcharge').text unless pack.css('calculatedcharge').text.empty?
          pack_info['customerdeliveringcode'] = pack.css('customerdeliveringcode').text unless pack.css('customerdeliveringcode').text.empty?
          pack_info['error_key'] = pack.css('error').attribute('key').value unless pack.css('error').empty?
          pack_info['error_message'] = pack.css('error').text unless pack.css('error').text.empty?

          sended_packs[pack_id] = pack_info
        end
      end

      return sended_packs
    end

    def generate_xml_for_data_packs(packs_data, auto_labels, self_send)
      xml = Builder::XmlMarkup.new

      xml.paczkomaty do
        xml.autoLabels auto_labels
        xml.selfSend self_send
        if packs_data.kind_of?(Array)
          packs_data.each {|pack|  xml = generate_xml_pack(xml,pack)}
        else
          xml = generate_xml_pack(xml,packs_data)
        end
      end

      return xml
    end

    def generate_xml_pack(xml,pack)
      xml.pack do
        xml.id pack.temp_id
        xml.adreseeEmail pack.adresee_email
        xml.senderEmail pack.sender_email
        xml.phoneNum pack.phone_num
        xml.boxMachineName pack.box_machine_name
        xml.alternativeBoxMachineName pack.alternative_box_machine_name unless pack.alternative_box_machine_name.nil?
        xml.packType pack.pack_type
        xml.customerDelivering(pack.customer_delivering.nil? ? false : pack.customer_delivering)
        xml.insuranceAmount pack.insurance_amount
        xml.onDeliveryAmount pack.on_delivery_amount
        xml.customerRef pack.customer_ref unless pack.customer_ref.nil?
        xml.senderBoxMachineName pack.sender_box_machine_name unless pack.sender_box_machine_name.nil?
        unless pack.sender_address.nil? || pack.sender_address.empty?
          xml.senderAddress do
            xml.name pack.sender_address[:name] unless pack.sender_address[:name]
            xml.surName pack.sender_address[:surname] unless pack.sender_address[:surname]
            xml.email pack.sender_address[:email] unless pack.sender_address[:email]
            xml.phoneNum pack.sender_address[:phone_num] unless pack.sender_address[:phone_num]
            xml.street pack.sender_address[:street] unless pack.sender_address[:street]
            xml.buildingNo pack.sender_address[:building_no] unless pack.sender_address[:building_no]
            xml.flatNo pack.sender_address[:flat_no] unless pack.sender_address[:flat_no]
            xml.town pack.sender_address[:town] unless pack.sender_address[:town]
            xml.zipCode pack.sender_address[:zip_code] unless pack.sender_address[:zip_code]
            xml.province pack.sender_address[:province] unless pack.sender_address[:province]
          end
        end
      end

      return xml
    end

    def cancel_pack(packcode)
      cancel_status = ''

      if packcode.empty?
        cancel_status = false
      else
        params = {:email => username, :digest => digest, :packcode => packcode}
        data = http_build_query(params)

        response = get_https_response(data,'/?do=cancelpack')

        xml = Nokogiri::XML(response)
        xml_error = xml.css('error')
        if xml_error.empty?
          cancel_status = response == 1 ? true : false
        else
          cancel_status = xml_error.text
        end
      end

      return cancel_status
    end

    def change_packsize(packcode, packsize)
      packsize_status = ''

      if packcode.empty? || packsize.empty?
        packsize_status = false
      else
        params = {:email => username, :digest => digest, :packcode => packcode, :packsize => packsize}
        data = http_build_query(params)

        response = get_https_response(data,'/?do=change_packsize')

        xml = Nokogiri::XML(response)
        xml_error = xml.css('error')
        if xml_error.empty?
          packsize_status = response == 1 ? true : false
        else
          packsize_status = xml_error.text
        end
      end

      return packsize_status
    end


    private

    def get_response(params)
      uri = URI.parse("#{PaczkomatyInpost.inpost_api_url}#{params}")
      response = Net::HTTP.get_response(uri)
      return response.body.gsub('"',"'").to_my_utf8
    end

    def get_https_response(params,path)
      https = Net::HTTP.new(PaczkomatyInpost.inpost_api_url.gsub('http://',''), 443)
      https.use_ssl = true
      https.verify_mode = OpenSSL::SSL::VERIFY_NONE
      headers = {'Content-Type'=> 'application/x-www-form-urlencoded'}
      response = https.post(path, params, headers)

      return response.body.gsub('"',"'").to_my_utf8
    end

    def http_build_query(data)
      params = []
      data.each do |k,v|
        params << "#{Rack::Utils.escape(k)}=#{Rack::Utils.escape(v)}"
      end

      return params.join('&')
    end
  end
end
