require 'paczkomaty_inpost/version'
require 'paczkomaty_inpost/inpost_api'
require 'paczkomaty_inpost/request'

module PaczkomatyInpost

  def self.options
    @options ||= {
      :username => nil,
      :password => nil,
      :data_path => nil
    }
  end

  def self.inpost_api_url
    @inpost_api_url ||= 'http://api.paczkomaty.pl'
  end
end
