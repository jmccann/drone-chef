require 'json'

module DroneChef
  #
  # Data provided by drone
  #
  class Drone
    attr_reader :data

    def initialize(data)
      @data = JSON.parse data
    end

    def write_configs
      write_netrc
    end

    def plugin_args
      @data['vargs']
    end

    def debug?
      return false if !!@data['vargs']['debug'] == @data['vargs']['debug'] # rubocop:disable DoubleNegation, LineLength
      @data['vargs']['debug']
    end

    private

    def netrc
      @data['workspace']['netrc']
    end

    def write_netrc
      File.open("#{Dir.home}/.netrc", 'w') do |f|
        f.puts "machine #{netrc['machine']}"
        f.puts "  login #{netrc['login']}"
        f.puts "  password #{netrc['password']}"
      end
    end
  end
end
