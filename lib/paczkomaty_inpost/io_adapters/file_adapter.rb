require 'json'

module PaczkomatyInpost

  class FileAdapter

    attr_accessor :data_path


    def initialize(data_path)
      self.data_path = Pathname.new(data_path)

      validate_path
    end

    def save_data(data)
      File.open(File.join(data_path, 'machines.dat'), 'w') do |f|
        f.write data.to_json
      end
    end

    def cached_data
      data = []
      if File.exist?(File.join(data_path, 'machines.dat'))
        data = JSON.parse(File.read(data_path + 'machines.dat'))
        data.shift
      end

      return data
    end

    def last_update
      data = 0
      if File.exist?(File.join(data_path, 'machines.dat'))
        data = JSON.parse(File.read(data_path + 'machines.dat'))[0]
      end

      return data
    end


    private

    def validate_path
      if data_path.nil? || !data_path.directory?
        raise Errno::ENOENT, "Invalid path given"
      end

      if data_path.nil? || !data_path.writable?
        raise Errno::EACCES, "Given path is not writeable"
      end
    end

  end
end
