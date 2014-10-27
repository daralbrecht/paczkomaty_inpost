# encoding: UTF-8
require "net/https"
require "uri"
require "csv"
require 'base64'
require 'digest/md5'
require 'builder'
require 'rack'
require 'timeout'

module PaczkomatyInpost

  class Request

    attr_accessor :username, :password


    def initialize(username, password)
      self.username = username
      self.password = password
    end

    def get_params
      params = {}

      uri = URI.parse("#{PaczkomatyInpost.inpost_api_url}/?do=getparams")
      begin
        response = Net::HTTP.get_response(uri)
      rescue SystemCallError
        raise Timeout::Error, 'Connection timeout while connecting to Paczkomaty API'
      end

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

    def download_machines
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

    def download_nearest_machines(postcode,paymentavailable)
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

    def download_pricelist
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

    def download_customer_preferences(email)
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

    def send_packs(packs_data, auto_labels, self_send)
      sended_packs = {}

      xml_packs_data = XmlGenerator.new.generate_xml_for_data_packs(packs_data, (auto_labels ? 1 : 0), (self_send ? 1 : 0))

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

    def cancel_pack(packcode)
      if empty_param?(packcode)
        return false
      else
        params = {:email => username, :digest => digest, :packcode => packcode}
        action_pack_status('/?do=cancelpack',params)
      end
    end

    def change_packsize(packcode, packsize)
      if empty_param?(packcode) || empty_param?(packsize)
        return false
      else
        params = {:email => username, :digest => digest, :packcode => packcode, :packsize => packsize}
        action_pack_status('/?do=change_packsize',params)
      end
    end

    def pay_for_pack(packcode)
      if empty_param?(packcode)
        return false
      else
        params = {:email => username, :digest => digest, :packcode => packcode}
        action_pack_status('/?do=payforpack',params)
      end
    end

    def set_customer_ref(packcode, customer_ref)
      if empty_param?(packcode) || empty_param?(customer_ref)
        return false
      else
        params = {:email => username, :digest => digest, :packcode => packcode, :customerref => customer_ref}
        action_pack_status('/?do=setcustomerref',params)
      end
    end

    def get_sticker(packcode,label_type)
      label_type = '' if label_type.nil?
      if empty_param?(packcode)
        return false
      else
        params = {:email => username, :digest => digest, :packcode => packcode, :labeltype => label_type}
        action_pack_status('/?do=getsticker',params)
      end
    end

    def get_stickers(packcodes,label_type)
      label_type = '' if label_type.nil?
      if empty_param?(packcodes)
        return false
      else
        params = {:email => username, :digest => digest, :packcodes => packcodes, :labeltype => label_type}
        action_pack_status('/?do=getstickers',params)
      end
    end

    def get_confirm_printout(packcodes,test_printout)
      if empty_param?(packcodes)
        return false
      else
        xml_packs_data = XmlGenerator.new.generate_xml_for_confirm_printout(packcodes, (test_printout ? 1 : 0))
        params = {:email => username, :digest => digest, :content => xml_packs_data.target!}
        action_pack_status('/?do=getconfirmprintout',params)
      end
    end

    def create_customer_partner(customer_data)
      if empty_param?(customer_data)
        return false
      else
        xml_customer = XmlGenerator.new.generate_xml_for_customer(customer_data)
        params = {:email => username, :digest => digest, :content => xml_customer.target!}
        action_pack_status('/?do=createcustomerpartner',params,customer_data[:email])
      end
    end

    def get_cod_report(start_date,end_date)
      if start_date.nil? || end_date.nil?
        return false
      else
        params = {:email => username, :digest => digest, :startdate => start_date, :enddate =>end_date}
        action_pack_status('/?do=getcodreport',params)
      end
    end

    def get_packs_by_sender(status,start_date,end_date,is_conf_printed)
      if start_date.nil? || end_date.nil? || status.nil?
        return false
      else
        if is_conf_printed == true
          conf_printed = '1'
        elsif is_conf_printed == false
          conf_printed = '0'
        else
          conf_printed = ''
        end
        params = {:email => username, :digest => digest, :status => status, :startdate => start_date, :enddate => end_date, :is_conf_printed => conf_printed}
        action_pack_status('/?do=getpacksbysender',params)
      end
    end

    def action_pack_status(action,params,key='')
      data = http_build_query(params)
      response = get_https_response(data,action)

      xml = Nokogiri::XML(response)
      xml_error = xml.css('error')
      if xml_error.empty?
        if action == '/?do=setcustomerref'
          status = response.include?('Set') ? true : false
        elsif ['/?do=getsticker', '/?do=getstickers', '/?do=getconfirmprintout'].include? action
          status = response.include?('PDF') ? response : false
        elsif action == '/?do=createcustomerpartner'
          status = response.include?(key) ? xml.css('email').text : false
        elsif action == '/?do=getcodreport'
          status = generate_cod_report(xml)
        elsif action == '/?do=getpacksbysender'
          status = generate_packs_for_sender(xml)
        else
          status = response == 1 ? true : false
        end
      else
        status = xml_error.text.empty? ? xml_error.attribute('key').text : xml_error.text
      end

      return status
    end



    private

    def get_response(params)
      params = URI.escape(params)
      uri = URI.parse("#{PaczkomatyInpost.inpost_api_url}#{params}")
      begin
        response = Net::HTTP.get_response(uri)
      rescue SystemCallError
        raise Timeout::Error, 'Connection timeout while connecting to Paczkomaty API'
      end

      return response.body.gsub('"',"'").to_my_utf8
    end

    def get_https_response(params,path)
      https = Net::HTTP.new(PaczkomatyInpost.inpost_api_url.gsub('http://',''), 443)
      https.use_ssl = true
      https.verify_mode = OpenSSL::SSL::VERIFY_NONE
      headers = {'Content-Type'=> 'application/x-www-form-urlencoded'}
      begin
        response = https.post(path, params, headers)
      rescue SystemCallError
        raise Timeout::Error, 'Connection timeout while connecting to Paczkomaty API'
      end

      return response.body.gsub('"',"'").to_my_utf8
    end

    def http_build_query(data,parent_key='')
      params = []
      if data.kind_of?(Array) && !parent_key.to_s.empty?
        data.each_with_index do |value, index|
          params << "#{Rack::Utils.escape(parent_key)}[#{index}]=#{Rack::Utils.escape(value)}"
        end
      elsif data.kind_of?(Hash)
        data.each do |key,value|
          if value.kind_of?(Array)
            params << http_build_query(value,key)
          else
            params << "#{Rack::Utils.escape(key)}=#{Rack::Utils.escape(value)}"
          end
        end
      end

      return params.join('&')
    end

    def empty_param?(param)
      param.nil? || param.empty?
    end

    def generate_cod_report(xml)
      payments = {}
      xml_payments = xml.css('payment')
      unless xml_payments.empty?
        xml_payments.each do |item|
          payment = {
            :amount => item.css('amount').text,
            :posdesc => item.css('posdesc').text,
            :packcode => item.css('packcode').text,
            :transactiondate => item.css('transactiondate').text.empty? ? '' : Time.parse(item.css('transactiondate').text)
          }
          payments[item.css('packcode').text] = payment
        end
      end

      return payments
    end

    def generate_packs_for_sender(xml)
      packs = {}
      xml_packs = xml.css('pack')
      unless xml_packs.empty?
        xml_packs.each do |item|
          next if item.css('packcode').text.empty?
          pack = {
            :packcode => item.css('packcode').text,
            :packsize => item.css('packsize').text,
            :amountcharged => item.css('amountcharged').text,
            :calculatedchargeamount => item.css('calculatedchargeamount').text,
            :creationdate => item.css('creationdate').text.empty? ? '' : Time.parse(item.css('creationdate').text),
            :labelcreationtime => item.css('labelcreationtime').text.empty? ? '' : Time.parse(item.css('labelcreationtime').text),
            :customerdeliveringcode => item.css('customerdeliveringcode').text,
            :status => item.css('status').text,
            :is_conf_printed => (item.css('is_conf_printed').text.present? && item.css('is_conf_printed').text == '1') ? true : false,
            :labelprinted => (item.css('labelprinted').text.present? && item.css('labelprinted').text == '1') ? true : false,
            :receiveremail => item.css('receiveremail').text,
            :ondeliveryamount => item.css('ondeliveryamount').text,
            :preferedboxmachinename => item.css('preferedboxmachinename').text,
            :alternativeboxmachinename => item.css('alternativeboxmachinename').text
          }
          packs[item.css('packcode').text] = pack
        end
      end

      return packs
    end

  end
end
