# encoding: UTF-8
require "net/https"
require "uri"
require "date"

module PaczkomatyInpost

  class InpostAPI

    attr_accessor :request, :data_adapter, :params


    def initialize(username, password, data_adapter)
      self.data_adapter = data_adapter
      self.request = PaczkomatyInpost::Request.new(username, password)
      inpost_check_environment
      inpost_get_params
    end

    def inpost_check_environment
      raise 'Used data adapter is not compatible with API' unless valid_data_adapter?
      raise 'You must use valid username' if request.username.nil? || request.username == ''
      raise 'Paczkomaty API: password cannot be empty' if request.password.nil? || request.password == ''
    end

    def valid_data_adapter?
      data_adapter.respond_to?(:save_machine_list) && data_adapter.respond_to?(:cached_machines) &&
      data_adapter.respond_to?(:save_price_list) && data_adapter.respond_to?(:cached_prices) &&
      data_adapter.respond_to?(:last_update_machines) && data_adapter.respond_to?(:last_update_prices) &&
      data_adapter.respond_to?(:save_pdf)
    end

    def inpost_get_params
      self.params = request.get_params
    end

    def inpost_machines_cache_is_valid?(update_params=true)
      inpost_get_params if update_params
      data_adapter.last_update_machines == params[:last_update]
    end

    def inpost_prices_cache_is_valid?(update_params=true)
      inpost_get_params if update_params
      data_adapter.last_update_prices == params[:last_update]
    end

    def inpost_update_machine_list
      inpost_get_params
      data = request.download_machines
      data_adapter.save_machine_list(data, params[:last_update])
    end

    def inpost_update_price_list
      inpost_get_params
      data = request.download_pricelist
      data_adapter.save_price_list(data, params[:last_update])
    end

    def inpost_get_machine_list(options={})
      list_options = {:town => nil, :paymentavailable => nil}.merge!(options)
      cache = data_adapter.cached_machines
      result_list = []
      unless cache.empty?
        cache.each do |machine|
          if list_options[:town] && list_options[:paymentavailable].nil?
            result_list << machine if (machine['town'].downcase == list_options[:town].downcase)
          elsif list_options[:town].nil? && !list_options[:paymentavailable].nil?
            result_list << machine if (machine['paymentavailable'] == list_options[:paymentavailable])
          elsif list_options[:town] && !list_options[:paymentavailable].nil?
            result_list << machine if ((machine['town'].downcase == list_options[:town].downcase) && (machine['paymentavailable'] == list_options[:paymentavailable]))
          else
            result_list << machine
          end
        end
      end

      return result_list
    end

    def inpost_get_pricelist
      data_adapter.cached_prices
    end

    def inpost_get_towns
      towns = []
      cache = data_adapter.cached_machines
      towns = cache.map{|item| item['town']}.compact.uniq.sort unless cache.empty?

      return towns
    end

    def inpost_find_nearest_machines(postcode,paymentavailable=nil)
      post_code = postcode.gsub(' ','')
      nearest_machines = request.download_nearest_machines(post_code,paymentavailable)
      cache = data_adapter.cached_machines
      result_list = []

      unless nearest_machines.empty? || cache.empty?
        nearest_machines.each_with_index do |machine, idx|
          result_list << cache.detect {|c| c['name'] == machine[:name]}
          return [] if result_list[idx].nil? # cache is out of date
          result_list[idx]['distance'] = machine[:distance].to_f
        end
        result_list = result_list.sort_by {|k| k['distance']} unless result_list.empty?
      end

      return result_list
    end

    def inpost_find_customer(email)
      request.download_customer_preferences(email)
    end

    def inpost_prepare_pack(temp_id, adresee_email, phone_num, box_machine_name, pack_type, insurance_amount, on_delivery_amount, options={})
      pack_options = {:customer_ref => nil, :alternative_box_machine_name => nil, :sender_address => nil,
                      :customer_delivering => nil, :sender_box_machine_name => nil}.merge!(options)
      pack = PaczkomatyInpost::InpostPack.new(:temp_id => temp_id,
                                              :adresee_email => adresee_email,
                                              :sender_email => request.username,
                                              :phone_num => phone_num,
                                              :box_machine_name => box_machine_name,
                                              :alternative_box_machine_name => pack_options[:alternative_box_machine_name],
                                              :customer_delivering => pack_options[:customer_delivering],
                                              :sender_box_machine_name => pack_options[:sender_box_machine_name],
                                              :pack_type => pack_type,
                                              :insurance_amount => insurance_amount,
                                              :on_delivery_amount => on_delivery_amount,
                                              :customer_ref => pack_options[:customer_ref],
                                              :sender_address => pack_options[:sender_address])
      raise "Invalid or missing parameters given when creating inpost pack." unless pack.valid?

      return pack
    end

    def inpost_send_packs(packs_data, options = {})
      send_options = {:auto_labels => true, :self_send => false}.merge!(options)
      request.send_packs(packs_data, send_options[:auto_labels], send_options[:self_send])
    end

    def inpost_get_pack_status(packcode)
      request.pack_status(packcode)
    end

    def inpost_cancel_pack(packcode)
      request.cancel_pack(packcode)
    end

    def inpost_change_packsize(packcode, packsize)
      request.change_packsize(packcode, packsize)
    end

    def inpost_pay_for_pack(packcode)
      request.pay_for_pack(packcode)
    end

    def inpost_set_customer_ref(packcode, customer_ref)
      request.set_customer_ref(packcode, customer_ref)
    end

    def inpost_get_sticker(packcode, options = {})
      sticker_options = {:sticker_path => nil, :label_type => ''}.merge!(options)
      sticker = request.get_sticker(packcode,sticker_options[:label_type])
      file_status(sticker, packcode, sticker_options[:sticker_path],'sticker')
    end

    def inpost_get_stickers(packcodes, options = {})
      sticker_options = {:stickers_path => nil, :label_type => ''}.merge!(options)
      stickers = request.get_stickers(packcodes,sticker_options[:label_type])
      file_status(stickers, packcodes, sticker_options[:stickers_path],'stickers')
    end

    def inpost_get_confirm_printout(packcodes, options = {})
      printout_options = {:printout_path => nil, :test_printout => false}.merge!(options)
      printout = request.get_confirm_printout(packcodes,printout_options[:test_printout])
      file_status(printout, packcodes, printout_options[:printout_path],'confirm_printout')
    end

    def inpost_create_customer_partner(options={})
      customer_options = {:email => nil,
                          :mobile_number => nil,
                          :prefered_box_machine_name => nil,
                          :alternative_box_machine_name => nil,
                          :phone_num => nil,
                          :street => nil,
                          :town => nil,
                          :post_code => nil,
                          :building => nil,
                          :flat => nil,
                          :first_name => nil,
                          :last_name => nil,
                          :company_name => nil,
                          :regon => nil,
                          :nip => nil}.merge!(options)
      if invalid_customer? customer_options
        raise 'Missing data for creating Inpost customer account!'
      else
        request.create_customer_partner(customer_options)
      end
    end

    def inpost_get_cod_report(options={})
      report_options = {:start_date => (DateTime.now - 60),
                        :end_date => (DateTime.now)}.merge!(options)
      request.get_cod_report(report_options[:start_date].strftime("%Y-%m-%d"),report_options[:end_date].strftime("%Y-%m-%d"))
    end


    private

    def file_status(file_content,packcodes,path,type)
      if file_content != false && file_content.include?('PDF')
        data_adapter.save_pdf(file_content, packcodes, path, type)
      else
        return file_content
      end
    end

    def invalid_customer?(customer_options)
      customer_options[:email].nil? || customer_options[:prefered_box_machine_name].nil? || customer_options[:post_code].nil? || customer_options[:phone_num].nil?
    end

  end
end