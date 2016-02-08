require 'fileutils'
require 'chef/cookbook/metadata'
require 'mixlib/shellout'

module DroneChef
  #
  # Class for uploading stuff to a Chef Server
  #
  class ChefServer
    def initialize(build_json)
      @config = DroneChef::Config.new build_json
      @options = @config.plugin_args
      fail 'ERROR: Chef organization required' unless @options.key? 'org'
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

    def berksfile?
      return true if File.exist? "#{@config.workspace}/Berksfile"
      return true if File.exist? "#{@config.workspace}/Berksfile.lock"
      false
    end

    def write_configs
      @config.write_configs
      write_knife_rb
      write_berks_config unless @config.ssl_verify
    end

    #
    # Upload to chef server
    #
    def upload
      berks_install if berksfile?
      berks_upload if berksfile?
      knife_upload unless cookbook? || !chef_data?
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
        f.puts "chef_repo_path '#{@config.workspace}'"
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
    # Command to gather necessary cookbooks
    #
    def berks_install
      puts 'Retrieving cookbooks'
      cmd = Mixlib::ShellOut.new("berks install -b #{@config.workspace}/Berksfile")
      cmd.run_command

      fail 'ERROR: Failed to retrieve cookbooks' if cmd.error?
    end

    #
    # Command to upload cookbook(s) with Berkshelf
    #
    def berks_upload # rubocop:disable AbcSize
      puts 'Running berks upload'
      command = ['berks upload']
      command << "#{cookbook.name}" unless recursive
      command << "-b #{@config.workspace}/Berksfile"
      command << '--no-freeze' unless freeze
      cmd = Mixlib::ShellOut.new(command.join(' '))
      cmd.run_command

      puts "DEBUG: berks upload stdout: #{cmd.stdout}" if @config.debug?
      fail 'ERROR: Failed to upload cookbook' if cmd.error?
    end

    def chef_data?
      !Dir.glob("#{@config.workspace}/{roles,environments,data_bags}").empty?
    end

    #
    # Upload any roles, environments and data_bags
    #
    def knife_upload
      puts 'Uploading roles, environments and data bags'
      command = ['knife upload']
      command << '.'
      command << "-c #{@config.knife_rb}"

      Dir.chdir(@config.workspace)

      cmd = Mixlib::ShellOut.new(command.join(' '))
      cmd.run_command

      puts "DEBUG: knife upload stdout: #{cmd.stdout}" if @config.debug?
      fail 'ERROR: knife upload failed' if cmd.error?
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
