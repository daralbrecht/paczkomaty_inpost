# encoding: UTF-8
require "net/https"
require "uri"

module PaczkomatyInpost

  class InpostAPI

    attr_accessor :request, :data_adapter, :params


    def initialize(request, data_adapter)
      self.data_adapter = data_adapter
      self.request = request
      self.params = self.request.inpost_get_params if request.respond_to?(:inpost_get_params)
    end

    def inpost_check_environment(verbose = false)
      valid_options = true
      errors = [] if verbose

      unless data_adapter.respond_to?(:save_data) && data_adapter.respond_to?(:cached_data)
        valid_options = false
        errors << 'Paczkomaty API: użyty data adapter jest niekompatybilny z API' if verbose
      end

      if !request.respond_to?(:username) || request.username.nil?
        valid_options = false
        errors << 'Paczkomaty API: nazwa użytkownika musi być zapisana w PaczkomatyInpost::Request' if verbose
      end

      if !request.respond_to?(:password) || request.password.nil?
        valid_options = false
        errors << 'Paczkomaty API: hasło musi być zapisane w PaczkomatyInpost::Request' if verbose
      end

      if verbose
        return valid_options, errors
      else
        return valid_options
      end
    end

    def inpost_cache_is_valid?
      request.inpost_get_params
      data_adapter.last_update == params[:last_update]
    end

    def inpost_update_machine_list
      request.inpost_get_params
      data = request.inpost_download_machines
      data.insert(0, params[:last_update])
      data_adapter.save_data(data)
    end

    def inpost_get_machine_list(town=nil,paymentavailable=nil)
      cache = data_adapter.cached_data
      result_list = []
      cache.each do |machine|
        if town && paymentavailable.nil?
          result_list << machine if (machine['town'].downcase == town.downcase)
        elsif town.nil? && !paymentavailable.nil?
          result_list << machine if (machine['paymentavailable'] == paymentavailable)
        elsif town && !paymentavailable.nil?
          result_list << machine if ((machine['town'].downcase == town.downcase) && (machine['paymentavailable'] == paymentavailable))
        else
          result_list << machine
        end
      end

      return result_list
    end

  end
end