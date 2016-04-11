require "pathname"
require "logger"

module Drone
  class Chef
    #
    # Chef plugin configuration
    #
    class Config
      extend Forwardable

      attr_accessor :payload, :logger

      delegate [:vargs, :workspace] => :payload,
               [:netrc] => :workspace,
               [:user, :private_key, :server,
                :org, :ssl_verify, :recursive] => :vargs

      #
      # Initialize an instance
      #
      def initialize(payload, logger = nil)
        self.payload = payload
        @logger = logger || Logger.new(STDOUT)
        @logger.level = Logger::DEBUG if debug?
      end

      #
      # Write config files to filesystem
      #
      def configure!
        write_keyfile
        write_netrc
      end

      #
      # Validate that all requirements are met
      #
      # @raise RuntimeError
      #
      def validate!
        raise "No plugin data found" if vargs.empty?

        raise "Please provide a username" if user.nil?
        raise "Please provide a private key" if private_key.nil?
        raise "Please provide a server URL" if server.nil?
      end

      #
      # Knife flag for enabling/disabling SSL verify
      #
      # @return [String]
      #
      def ssl_mode
        ssl_verify? ? ":verify_peer" : ":verify_none"
      end

      #
      # Flag on wheter to use SSL verification
      #
      # @return [TrueClass, FalseClass]
      #
      def ssl_verify?
        if vargs.ssl_verify.nil?
          true
        else
          vargs.ssl_verify?
        end
      end

      #
      # Get freeze for Chef
      #
      # @return [TrueClass, FalseClass]
      #
      def freeze?
        if vargs["freeze"].nil?
          true
        else
          vargs["freeze"]
        end
      end

      #
      # Get recursive for Chef
      #
      # @return [TrueClass, FalseClass]
      #
      def recursive?
        if vargs.recursive.nil?
          true
        else
          vargs.recursive?
        end
      end

      #
      # Determine if we are debugging
      #
      # @return [TrueClass, FalseClass]
      #
      def debug?
        if vargs.debug.nil?
          false
        else
          ENV["DEBUG"] == "true" || vargs.debug?
        end
      end

      #
      # Knife config file location
      #
      def knife_config_path
        @knife_config_path ||= Pathname.new(
          Dir.home
        ).join(
          ".chef",
          "knife.rb"
        )

        @knife_config_path.dirname.tap do |dir|
          dir.mkpath unless dir.directory?
        end

        @knife_config_path
      end

      #
      # Berkshelf config file location
      #
      def berks_config_path
        @berks_config_path ||= Pathname.new(
          Dir.home
        ).join(
          ".berkshelf",
          "config.json"
        )

        @berks_config_path.dirname.tap do |dir|
          dir.mkpath unless dir.directory?
        end

        @berks_config_path
      end

      #
      # The path to write our knife keyfile to
      #
      def keyfile_path
        @keyfile_path ||= Pathname.new(
          "/tmp/key.pem"
        )
      end

      protected

      #
      # Write a knife keyfile
      #
      def write_keyfile
        keyfile_path.open "w" do |f|
          f.write private_key
        end
      end

      #
      # The path to write our netrc config to
      #
      def netrc_path
        @netrc_path ||= Pathname.new(
          Dir.home
        ).join(
          ".netrc"
        )
      end

      #
      # Write a .netrc file
      #
      def write_netrc
        return if netrc.nil?
        netrc_path.open "w" do |f|
          f.puts "machine #{netrc.machine}"
          f.puts "  login #{netrc.login}"
          f.puts "  password #{netrc.password}"
        end
      end
    end
  end
end
