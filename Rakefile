# rubocop:disable LineLength, WordArray

require 'json'
require 'shellwords'

#
# Override Hash class to add deep_merge method for recursive merging
#
class Hash
  def deep_merge(second)
    merger = proc { |_key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2 } # rubocop:disable CaseEquality
    merge(second, &merger)
  end
end

# Parse common JSON for build from JSON file
def common_json
  @common ||= JSON.parse File.read 'test/common.json'
end

# @return the directory this Rakefile exists in
def base_dir
  File.dirname(__FILE__)
end

# @return the directory for our test cookbook
def cookbook_path
  "#{base_dir}/test/chef_cookbook"
end

# @return the user to auth with
def user
  ENV['CHEF_USER'] || fail('User not set')
end

# @return the key to auth with
def key
  ENV['CHEF_KEY'].tr("\\\\\n", "\n").gsub(/^n/, '') || fail('Key not set')
end

# @return [String] the server to upload to
def server
  ENV['CHEF_SERVER'] || fail('Server not set')
end

# @return [Hash] basic vargs to assume some defaults
def basic_config
  common_json.merge(
    'vargs' => {
      'user' => user,
      'key' => key,
      'server' => server,
      'ssl_verify' => false
    }
  )
end

namespace :cleanup do
  desc 'Unshare test cookbook'
  task :cookbook do
    sh 'knife supermarket unshare drone-plugin-test -y || exit 0'
  end
end

desc 'Cleanup'
task cleanup: ['cleanup:cookbook']

namespace :build do
  desc 'Build docker container'
  task :docker do
    sh 'docker build --rm=true -t drone-plugins/drone-chef .'
  end
end

desc 'Build'
task build: ['build:docker']

namespace :test do
  desc 'Perform basic cookbook upload tests'
  task :basic do
    verbose(false) do
      puts 'Performing initial upload'
      sh "docker run -v #{cookbook_path}:/drone/src/github.com/drone/drone -i drone-plugins/drone-chef ARVG[0] #{Shellwords.escape(basic_config.to_json)}"
      puts ''
      puts 'Making sure cookbook was uploaded'
      sh 'knife supermarket show drone-plugin-test'
      puts ''
      puts 'Performing conflicting upload'
      sh "docker run -v #{cookbook_path}:/drone/src/github.com/drone/drone -i drone-plugins/drone-chef ARVG[0] #{Shellwords.escape(basic_config.to_json)}"
      puts ''
      puts 'Performing conflicting upload with debug'
      sh "docker run -v #{cookbook_path}:/drone/src/github.com/drone/drone -i drone-plugins/drone-chef ARVG[0] #{Shellwords.escape(basic_config.deep_merge('vargs' => { 'debug' => true }).to_json)} | grep DEBUG"
    end
  end
end

desc 'Test'
task test: ['test:basic']

task default: ['cleanup', 'build', 'test']
