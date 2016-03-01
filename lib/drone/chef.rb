module Drone
  class Chef
    autoload :Config,
      File.expand_path("../chef/config", __FILE__)

    autoload :Processor,
      File.expand_path("../chef/processor", __FILE__)

    attr_accessor :config

    #
    # Initialize an instance
    #
    def initialize(payload)
      self.config = Config.new(
        payload
      )
    end

    #
    # General plugin execution
    #
    def execute!
      config.validate!

      Processor.new config do |processor|
        processor.validate!
        processor.configure!
        processor.upload!
      end
    end
  end
end
