IMAGE_NAME = "jmccann/drone-chef:0.5".freeze

begin
  require "bundler"
  Bundler::GemHelper.install_tasks
rescue LoadError
  warn "Failed to load bundler tasks"
end

require "rubocop/rake_task"
RuboCop::RakeTask.new(:rubocop) do |task|
  task.options = [
    "-c",
    ".rubocop.yml"
  ]
end

require "rspec/core/rake_task"
RSpec::Core::RakeTask.new(:spec)

require "yard"
YARD::Rake::YardocTask.new

desc "Build docker container"
task :docker do
  sh "docker build --rm=true -t #{IMAGE_NAME} ."
end

task default: [:build, :spec, :rubocop]
