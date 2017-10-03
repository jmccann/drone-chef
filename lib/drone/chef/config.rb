require "logger"
require "openssl"
require "pathname"

module Drone
  class Chef
    #
    # Chef plugin configuration
    #
    class Config
      attr_accessor :payload, :logger

      #
      # Initialize an instance
      #
      def initialize(payload, log = nil)
        self.payload = payload
        self.logger = log || default_logger
      end

      #
      # The path to our git workspace
      #
      def workspace_path
        @workspace_path ||= Pathname.new Dir.pwd
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
      def validate! # rubocop:disable AbcSize
        raise "Missing 'user'" if missing?(:user)
        raise "Missing 'server'" if missing?(:server)
        raise "Missing 'org'" if missing?(:org)

        raise "Missing CHEF_PRIVATE_KEY" if missing?(:private_key)
        ::OpenSSL::PKey::RSA.new payload[:private_key]
      rescue OpenSSL::PKey::RSAError
        raise "Failed to load CHEF_PRIVATE_KEY provided starting with:" \
              "\n#{payload[:private_key][0, 35]}"
      end

      #
      # Knife flag for enabling/disabling SSL verify
      #
      # @return [String]
      #
      def ssl_mode
        payload[:ssl_verify] ? ":verify_peer" : ":verify_none"
      end

      #
      # Knife config file location
      #
      def knife_config_path
        @knife_config_path ||= Pathname.new(
          home
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
          home
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

      def home
        Dir.home
      end

      protected

      def default_logger
        @logger ||= Logger.new(STDOUT).tap do |l|
          l.level = payload[:debug] ? Logger::DEBUG : Logger::INFO
          l.formatter = proc do |sev, datetime, _progname, msg|
            "#{sev}, [#{datetime}] : #{msg}\n"
          end
        end
      end

      def berks_files_exist?
        vargs.berks_files.each do |f|
          unless File.exist? "#{workspace.path}/#{f}"
            raise "Berksfile '#{f}' does not exist"
          end
        end
      end

      #
      # Write a knife keyfile
      #
      def write_keyfile
        keyfile_path.open "w" do |f|
          f.write payload[:private_key]
        end
      end

      #
      # The path to write our netrc config to
      #
      def netrc_path
        @netrc_path ||= Pathname.new(
          home
        ).join(
          ".netrc"
        )
      end

      #
      # Write a .netrc file
      #
      def write_netrc
        return if ENV["DRONE_NETRC_MACHINE"].nil? || File.exist?(netrc_path)
        netrc_path.open "w" do |f|
          f.puts "machine #{ENV["DRONE_NETRC_MACHINE"]}"
          f.puts "  login #{ENV["DRONE_NETRC_USERNAME"]}"
          f.puts "  password #{ENV["DRONE_NETRC_PASSWORD"]}"
        end
      end

      def missing?(key)
        payload[key].nil? || payload[key].empty?
      end
    end
  end
end
