require "fileutils"
require "chef/cookbook/metadata"
require "mixlib/shellout"

module Drone
  class Chef
    #
    # Class for uploading cookbooks to a Chef Server
    #
    class Processor # rubocop:disable ClassLength
      attr_accessor :config

      #
      # Initialize an instance
      #
      def initialize(config)
        self.config = config

        yield(self) if block_given?
      end

      #
      # Validate that all requirements are met
      #
      def validate!
        config.validate!
        # raise "Please provide an organization" if config.payloadorg.nil?
      end

      #
      # Write required config files
      #
      def configure!
        config.configure!

        write_knife_rb
        write_berks_config
      end

      #
      # Upload the cookbook and envs/roles/etc to a Chef Server
      #
      def upload!
        berks_install if berksfile?
        berks_upload if berksfile?
        knife_upload if chef_data?
      end

      #
      # Is there a Berksfile?
      #
      def berksfile?
        config.payload[:berks_files].each do |f|
          return true if File.exist? "#{config.workspace_path}/#{f}"
          return true if File.exist? "#{config.workspace_path}/#{f}.lock"
        end
        false
      end

      protected

      #
      # Are we uploading a cookbook?
      #
      def cookbook?
        File.exist? "#{config.workspace_path}/metadata.rb"
      end

      def url
        "#{config.payload[:server]}/organizations/#{config.payload[:org]}"
      end

      def write_knife_rb # rubocop:disable AbcSize
        config.knife_config_path.open "w" do |f|
          f.puts "node_name '#{config.payload[:user]}'"
          f.puts "client_key '#{config.keyfile_path}'"
          f.puts "chef_server_url '#{url}'"
          f.puts "chef_repo_path '#{config.workspace_path}'"
          f.puts "ssl_verify_mode #{config.ssl_mode}"
        end
      end

      def write_berks_config
        return if config.payload[:ssl_verify]
        config.berks_config_path.open "w" do |f|
          f.puts '{"ssl":{"verify":false}}'
        end
      end

      #
      # Command to gather necessary cookbooks
      #
      def berks_install
        config.payload[:berks_files].each do |f|
          berks_install_for f
        end
      end

      def berks_install_for(f)
        logger.info "Retrieving cookbooks for #{f}"
        cmd = Mixlib::ShellOut
              .new("berks install -b #{config.workspace_path}/#{f}")
        cmd.run_command

        logger.error cmd.stdout + cmd.stderr if cmd.error?
        raise "ERROR: Failed to retrieve cookbooks" if cmd.error?
      end

      #
      # Command to upload cookbook(s) with Berkshelf
      #
      def berks_upload
        config.payload[:berks_files].each do |f|
          berks_upload_for f
        end
      end

      def berks_upload_for(f) # rubocop:disable AbcSize, MethodLength
        logger.info "Running berks upload for #{f}"
        command = ["berks upload"]
        command << cookbook.name if cookbook? && !config.payload[:recursive]
        command << "-b #{config.workspace_path}/#{f}"
        command << "--no-freeze" unless config.payload[:freeze]

        cmd = Mixlib::ShellOut.new(command.join(" "))
        cmd.run_command

        logger.debug "berks_upload_for(#{f}) cmd: #{command.join(" ")}"
        logger.error cmd.stderr if cmd.error?
        logger.info "\n#{cmd.stdout}"

        raise "ERROR: Failed to upload cookbook" if cmd.error?
      end

      def chef_data?
        !Dir.glob("#{config.workspace_path}/{roles,environments,data_bags}")
            .empty?
      end

      #
      # Upload any roles, environments and data_bags
      #
      def knife_upload # rubocop:disable AbcSize
        logger.info "Uploading roles, environments and data bags"
        command = ["knife upload"]
        command << "."
        command << "-c #{config.knife_config_path}"

        Dir.chdir(config.workspace_path)

        cmd = Mixlib::ShellOut.new(command.join(" "))
        cmd.run_command

        logger.debug "knife_upload cmd: #{command.join(" ")}"
        logger.info "\n#{cmd.stdout}"

        raise "ERROR: knife upload failed" if cmd.error?
      end

      def cookbook
        @metadata ||= begin
          metadata = ::Chef::Cookbook::Metadata.new
          metadata.from_file("#{config.workspace_path}/metadata.rb")
          metadata
        end
      end

      def logger
        config.logger
      end
    end
  end
end
