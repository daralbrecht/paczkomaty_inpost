require "net/https"
require "uri"

module PaczkomatyInpost

  class Request

    attr_accessor :username, :password


    def initialize(username, password)
      self.username = username
      self.password = password
    end

  end
end
