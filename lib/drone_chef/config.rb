require 'fileutils'

module DroneChef
  #
  # Plugin configuration
  #
  class Config
    attr_reader :plugin_args

    def initialize(build_json)
      @data = JSON.parse build_json
      @plugin_args = @data['vargs']
      verify_reqs
    end

    def write_configs
      write_netrc
      write_key
    end

    def plugin_args
      @data['vargs']
    end

    def boolean?(arg)
      !!arg == arg # rubocop:disable DoubleNegation
    end

    def debug?
      return false unless boolean?(@data['vargs']['debug']) || env_debug?
      @data['vargs']['debug'] || env_debug?
    end

    def workspace
      @data['workspace']['path']
    end

    def server
      @plugin_args['server']
    end

    def type
      set_default(__method__, 'supermarket')
    end

    def user
      @plugin_args['user']
    end

    def key_path
      '/tmp/key.pem'
    end

    def ssl_verify
      set_default(__method__, true)
    end

    def ssl_verify_mode
      ssl_verify ? ':verify_peer' : ':verify_none'
    end

    def knife_rb
      "#{Dir.home}/.chef/knife.rb"
    end

    private

    #
    # Returns default value if one isn't provided
    #
    # @param key [String] The key to check a value for
    # @param default_value The default value to return if none provided
    #
    # @return Returns the value provided in @plugin_args[key] if provided,
    #   else returns default_value
    #
    def set_default(key, default_value)
      return default_value unless @plugin_args.key? key.to_s
      @plugin_args[key.to_s]
    end

    def key
      @plugin_args['key']
    end

    #
    # Verify necessary data was provided
    #
    def verify_reqs
      puts 'INFO: Verifying required arguments'
      fail 'No build data found' if @plugin_args.nil?
      fail 'Username required' unless @plugin_args.key? 'user'
      fail 'Key required' unless @plugin_args.key? 'key'
      fail 'Server URL required' unless @plugin_args.key? 'server'
    end

    def write_key
      puts 'INFO: Writing temp key'
      File.open(key_path, 'w') do |f|
        f.write key
      end
    end

    def env_debug?
      ENV['DEBUG'] == 'true'
    end

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
