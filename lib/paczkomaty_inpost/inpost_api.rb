# encoding: UTF-8
require "net/https"
require "uri"

module PaczkomatyInpost

  class InpostAPI

    attr_accessor :request, :data_adapter, :params


    def initialize(username, password, data_adapter)
      self.data_adapter = data_adapter
      self.request = PaczkomatyInpost::Request.new(username, password)

      inpost_check_environment

      self.params = self.request.inpost_get_params
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
      data_adapter.respond_to?(:save_sticker)
    end

    def inpost_machines_cache_is_valid?
      request.inpost_get_params
      data_adapter.last_update_machines == params[:last_update]
    end

    def inpost_prices_cache_is_valid?
      request.inpost_get_params
      data_adapter.last_update_prices == params[:last_update]
    end

    def inpost_update_machine_list
      request.inpost_get_params
      data = request.inpost_download_machines
      data_adapter.save_machine_list(data, params[:last_update])
    end

    def inpost_update_price_list
      request.inpost_get_params
      data = request.inpost_download_pricelist
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
      nearest_machines = request.inpost_download_nearest_machines(post_code,paymentavailable)
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
      request.inpost_download_customer_preferences(email)
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
      if sticker != false && sticker.include?('PDF')
        data_adapter.save_sticker(sticker,packcode,sticker_options[:sticker_path])
      else
        return sticker
      end
    end

  end
end