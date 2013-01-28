# encoding: UTF-8
require 'paczkomaty_inpost/version'
require 'paczkomaty_inpost/inpost_api'
require 'paczkomaty_inpost/request'
require 'paczkomaty_inpost/io_adapters/file_adapter'

module PaczkomatyInpost

  def self.inpost_api_url
    @inpost_api_url ||= 'http://api.paczkomaty.pl'
  end
end
