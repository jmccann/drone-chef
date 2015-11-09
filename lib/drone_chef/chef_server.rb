require 'fileutils'
require 'chef/cookbook/metadata'

module DroneChef
  #
  # Class for uploading stuff to a Chef Server
  #
  class ChefServer
    def initialize(config)
      @config = config
      @options = config.plugin_args
      fail 'Chef organization required' unless @options.key? 'org'
    end

    def recursive
      set_default(__method__, true)
    end

    def freeze
      set_default(__method__, true)
    end

    #
    # Are we uploading a cookbook?
    #
    def cookbook?
      File.exist? "#{@config.workspace}/metadata.rb"
    end

    def write_configs
      @config.write_configs
      write_knife_rb
      write_berks_config unless @config.ssl_verify
    end

    def upload
      berks_install
      berks_upload
      # roles.upload unless cookbook?
      # environments.upload unless cookbook?
      # data_bags.upload unless cookbook?
    end

    private

    #
    # Returns default value if one isn't provided
    #
    # @param key [String] The key to check a value for
    # @param default_value The default value to return if none provided
    #
    # @return Returns the value provided in @options[key] if provided,
    #   else returns default_value
    #
    def set_default(key, default_value)
      return default_value unless @options.key? key.to_s
      @options[key.to_s]
    end

    def url
      "#{@config.server}/organizations/#{@options['org']}"
    end

    def write_knife_rb
      FileUtils.mkdir_p File.dirname @config.knife_rb
      File.open(@config.knife_rb, 'w') do |f|
        f.puts "node_name '#{@config.user}'"
        f.puts "client_key '#{@config.key_path}'"
        f.puts "chef_server_url '#{url}'"
        f.puts "ssl_verify_mode #{@config.ssl_verify_mode}"
      end
    end

    def write_berks_config
      FileUtils.mkdir_p "#{Dir.home}/.berkshelf"
      File.open("#{Dir.home}/.berkshelf/config.json", 'w') do |f|
        f.puts '{"ssl":{"verify":false}}'
      end
    end

    #
    # Command to generate Berkshelf lockfile
    #
    def berks_install
      return if File.exist? "#{@config.workspace}/Berksfile.lock"
      puts 'Generating Berksfile.lock'
      `berks install -b #{@config.workspace}/Berksfile`
      fail 'Failed to generate berks lockfile' unless process_last_status.success?
    end

    #
    # Command to upload cookbook(s) with Berkshelf
    #
    def berks_upload
      puts 'Running berks upload'
      command = ['berks upload']
      command << "#{cookbook.name}" unless recursive
      command << "-b #{@config.workspace}/Berksfile"
      command << '--no-freeze' unless freeze
      puts `#{command.join(' ')}`
      fail 'Failed to upload cookbook' unless process_last_status.success?
    end

    def process_last_status
      $?
    end

    def cookbook
      @metadata ||= begin
        metadata = Chef::Cookbook::Metadata.new
        metadata.from_file("#{@config.workspace}/metadata.rb")
        metadata
      end
    end
  end
end
