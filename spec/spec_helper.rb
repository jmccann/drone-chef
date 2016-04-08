require "fakefs/spec_helpers"
require "pry"
require "simplecov"
require "simplecov-lcov"

SimpleCov::Formatter::LcovFormatter.tap do |config|
  config.report_with_single_file = true
end

SimpleCov.start do
  add_filter "/spec"
  add_filter "/gems"

  formatter SimpleCov::Formatter::MultiFormatter.new [
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::LcovFormatter
  ]
end

require "drone/chef"
require "rspec"

RSpec.configure do |config|
  config.mock_with :rspec
  config.order = "random"
end
