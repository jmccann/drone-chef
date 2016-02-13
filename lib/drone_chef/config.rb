require 'fileutils'

module DroneChef
  #
  # Plugin configuration
  #
  class Config
    attr_reader :data

    def initialize(build_json)
      @data = JSON.parse build_json
      verify_reqs
    end

    #
    # Write config files such as netrc and knife keyfile
    #
    def write_configs
      write_netrc
      write_key
    end

    #
    # Determine if we are running with debugging
    #
    # @return [TrueClass, FalseClass]
    #
    def debug?
      return false unless boolean?(@data['vargs']['debug']) || env_debug?
      @data['vargs']['debug'] || env_debug?
    end

    #
    # Path to the workspace
    #
    def workspace
      @data['workspace']['path']
    end

    #
    # Server to upload to
    #
    def server
      @data['vargs']['server']
    end

    #
    # Type of server to upload to
    #
    def type
      set_default(__method__, 'supermarket')
    end

    #
    # User to auth to server as
    #
    def user
      @data['vargs']['user']
    end

    #
    # The path to write our knife keyfile to
    #
    def key_path
      '/tmp/key.pem'
    end

    #
    # Flag on wheter to use SSL verification
    #
    # @return [TrueClass, FalseClass]
    #
    def ssl_verify
      set_default(__method__, true)
    end

    #
    # Knife flag for enabling/disabling SSL verify
    #
    # @return [String]
    #
    def ssl_verify_mode
      ssl_verify ? ':verify_peer' : ':verify_none'
    end

    #
    # Knife config file location
    #
    def knife_rb
      "#{Dir.home}/.chef/knife.rb"
    end

    private

    #
    # Determine if arg is a true/false boolean
    #
    # @param [Object] Object to check TrueClass/FalseClass of
    #
    # @return [TrueClass, FalseClass] return TrueClass if Object was TrueClass or FalseClass,
    #   otherwise return FalseClass
    #
    def boolean?(arg)
      !!arg == arg # rubocop:disable DoubleNegation
    end

    #
    # Returns default value if one isn't provided
    #
    # @param key [String] The key to check a value for
    # @param default_value The default value to return if none provided
    #
    # @return Returns the value provided in @data['vargs'][key] if provided,
    #   else returns default_value
    #
    def set_default(key, default_value)
      return default_value unless @data['vargs'].key? key.to_s
      @data['vargs'][key.to_s]
    end

    def key
      @data['vargs']['key']
    end

    #
    # Verify necessary data was provided
    #
    def verify_reqs
      puts 'INFO: Verifying required arguments'
      fail 'No build data found' if @data['vargs'].nil?
      fail 'Username required' unless @data['vargs'].key? 'user'
      fail 'Key required' unless @data['vargs'].key? 'key'
      fail 'Server URL required' unless @data['vargs'].key? 'server'
    end

    #
    # Write knife keyfile
    #
    def write_key
      puts 'INFO: Writing temp key'
      File.open(key_path, 'w') do |f|
        f.write key
      end
    end

    #
    # Check ENV if DEBUG is set
    #
    # @return [TrueClass, FalseClass]
    #
    def env_debug?
      ENV['DEBUG'] == 'true'
    end

    #
    # Datastructure of netrc info from Drone
    #
    def netrc
      @data['workspace']['netrc']
    end

    #
    # Write .netrc file
    #
    def write_netrc
      File.open("#{Dir.home}/.netrc", 'w') do |f|
        f.puts "machine #{netrc['machine']}"
        f.puts "  login #{netrc['login']}"
        f.puts "  password #{netrc['password']}"
      end
    end
  end
end
