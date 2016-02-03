require 'fileutils'

module DroneChef
  #
  # Plugin configuration
  #
  class Config
    attr_reader :plugin_args

    def initialize(drone)
      @drone = drone
      @plugin_args = drone.plugin_args
      verify_reqs
    end

    def workspace
      @drone.data['workspace']['path']
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

    def write_configs
      @drone.write_configs
      write_key
    end

    def knife_rb
      "#{Dir.home}/.chef/knife.rb"
    end

    def debug?
      @drone.debug?
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
      puts 'Verifying required arguments'
      fail 'No build data found' if @plugin_args.nil?
      fail 'Username required' unless @plugin_args.key? 'user'
      fail 'Key required' unless @plugin_args.key? 'key'
      fail 'Server URL required' unless @plugin_args.key? 'server'
    end

    def write_key
      puts 'Writing temp key'
      File.open(key_path, 'w') do |f|
        f.write key
      end
    end
  end
end
